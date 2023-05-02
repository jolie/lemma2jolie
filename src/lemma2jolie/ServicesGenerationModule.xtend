package lemma2jolie

import de.fhdo.lemma.model_processing.annotations.CodeGenerationModule
import de.fhdo.lemma.model_processing.phases.ModelKind
import de.fhdo.lemma.model_processing.UtilKt
import de.fhdo.lemma.model_processing.builtin_phases.code_generation.AbstractCodeGenerationModule
import de.fhdo.lemma.service.ServicePackage
import de.fhdo.lemma.service.ServiceModel
import de.fhdo.lemma.service.ImportType
import de.fhdo.lemma.utils.LemmaUtils
import de.fhdo.lemma.data.DataDslStandaloneSetup
import java.io.FileInputStream
import de.fhdo.lemma.data.DataModel
import org.apache.commons.io.FilenameUtils
import java.io.File
import java.nio.charset.StandardCharsets
import de.fhdo.lemma.service.Interface
import de.fhdo.lemma.service.Operation
import de.fhdo.lemma.technology.ExchangePattern
import de.fhdo.lemma.data.ComplexType
import de.fhdo.lemma.data.PrimitiveType
import de.fhdo.lemma.technology.CommunicationType
import de.fhdo.lemma.data.Context
import java.util.Set
import de.fhdo.lemma.service.Parameter

/**
 * LEMMA code generation module to derive Jolie code from a LEMMA service model. The service model
 * must be passed as a source model to the generator using the "-s" commandline option. Furthermore,
 * the module must be explicitly executed using the "--invoke_only_specified_modules services"
 * commandline argument. The resulting Jolie program will have the same name as the passed service
 * model but with the ".ol" extension.
 */
@CodeGenerationModule(name="services", modelKinds=ModelKind.SOURCE)
class ServicesGenerationModule extends AbstractCodeGenerationModule {
    val availableComplexTypes = <String, Set<String>>newHashMap
    var ParameterTypesManager parameterTypesManager = null

    /**
     * Helper class to collect types generated from LEMMA operation parameters
     */
    private static class ParameterTypesManager {
        val types = <String, String>newHashMap

        /**
         * Register type for synchronous parameters with a given exchange pattern of the given LEMMA
         * operation. All synchronous parameters with the pattern are clustered in a compound type.
         */
        def registerTypeForSynchronousParameters(Operation operation, ExchangePattern pattern) {
            val typeName = '''«operation.name»_«pattern.literal.toLowerCase»'''
            types.put(keyFrom(operation, pattern), typeName)
            return typeName
        }

        /**
         * Helper to generate a unique key for synchronous parameters with a given exchange pattern
         * of the given LEMMA operation
         */
        private def keyFrom(Operation operation, ExchangePattern pattern) {
            '''«operation.buildQualifiedName(".")»$«pattern.literal»'''.toString
        }

        /**
         * Retrieve the compound type for all synchronous parameters with a given exchange pattern
         * of the given LEMMA operation
         */
        def getTypeForSynchronousParameters(Operation operation, ExchangePattern pattern) {
            return types.get(keyFrom(operation, pattern))
        }

        /**
         * Register type for an asynchronous parameter. Each asynchronous parameter of a LEMMA
         * operation is clustered in its own type.
         */
        def registerTypeForAsynchronousParameter(Parameter parameter) {
            val operation = parameter.operation
            val pattern = parameter.exchangePattern
            val typeName = '''«operation.name»_«pattern.literal.toLowerCase»_«parameter.name»'''
            types.put(keyFrom(parameter), typeName)
            return typeName
        }

        /**
         * Helper to generate a unique key for an asynchronous parameter of a LEMMA operation
         */
        private def keyFrom(Parameter parameter) {
            parameter.buildQualifiedName(".")
        }

        /**
         * Retrieve compound type the given asynchronous parameter of a LEMMA operation
         */
        def getTypeForAsynchronousParameter(Parameter parameter) {
            return types.get(keyFrom(parameter))
        }
    }

    /**
     * Return language namespace for parsing LEMMA service models
     */
    override getLanguageNamespace() {
        return ServicePackage.eNS_URI
    }

    /**
     * Execution logic of the module
     */
    override execute(String[] phaseArguments, String[] moduleArguments) {
        availableComplexTypes.clear
        parameterTypesManager = new ParameterTypesManager()

        val model = resource.contents.get(0) as ServiceModel
        val generatedModelContents = newArrayList(generateDomainContexts(model))

        model.microservices
            .map[it.interfaces]
            .flatten
            .forEach[
                try {
                    generatedModelContents.add((it as Interface).generateInterface.toString)
                } catch (InvalidParameterTypeException ex) {
                    println(ex.message)
                }
            ]

        val baseFileName = FilenameUtils.getBaseName(modelFile)
        val targetFile = '''«targetFolder»«File.separator»«baseFileName».ol'''
        return withCharset(#{targetFile -> generatedModelContents.join("\n")},
            StandardCharsets.UTF_8.name)
    }

    /**
     * Generate Jolie types and interfaces for all LEMMA domain models imported by the given LEMMA
     * service model. This generation step ensures that the Jolie code produced for LEMMA
     * microservices can access these types.
     */
    private def generateDomainContexts(ServiceModel serviceModel) {
        val generatedContexts = new StringBuffer

        serviceModel.imports.filter[it.importType == ImportType.DATATYPES].forEach[
            // Load the imported domain model
            val importedDomainModelUri = LemmaUtils.absoluteFileUriFromResourceBase(it.importURI,
                serviceModel.eResource)
            val importedDomainModelPath = LemmaUtils.removeFileUri(importedDomainModelUri)
            val domainModel = loadDomainModel(importedDomainModelPath)
            val importAlias = it.name

            // Generate the domain model types per bounded context using the domain generation
            // module
            domainModel.contexts.forEach[
                val generationModule = new DomainGenerationModule()
                generatedContexts.append(generationModule.generateContext(it as Context))
                val generatedComplexTypes = generationModule.generatedComplexTypesNames
                availableComplexTypes.put(importAlias, generatedComplexTypes)
            ]
        ]

        return generatedContexts.toString
    }

    /**
     * Helper to load a LEMMA domain model from the given model path
     */
    private def loadDomainModel(String modelPath) {
        val modelInputStream = new FileInputStream(UtilKt.asFile(modelPath))
        val resource = UtilKt.loadXtextResource(new DataDslStandaloneSetup, modelPath,
               modelInputStream)
        return resource.contents.get(0) as DataModel
    }

    /**
     * Encode a LEMMA interface as Jolie types, interfaces, and operations
     */
    private def generateInterface(Interface iface) {
        // Don't gather the operation types via map() because we need generateOperationTypes() to
        // register types prior to the generation of operations that require these types. map(),
        // however, relies on lazy evaluation so that types may not be available when
        // generateOperations() is called (but only afterwards when operationTypes is accessed in
        // the template at the end of the method).
        val operationTypes = <String>newArrayList
        for (o : iface.operations)
            operationTypes.add(o.generateOperationTypes.toString)

        val oneWays = <String>newArrayList
        val requestResponses = <String>newArrayList
        iface.operations.forEach[
            val generatedOperations = it.generateOperations
            oneWays.addAll(generatedOperations.key)
            requestResponses.addAll(generatedOperations.value)
        ]

        '''
        ///@interface(«iface.buildQualifiedName(".")»)
        «FOR t : operationTypes»
            «t»
        «ENDFOR»
        interface «iface.microservice.name.replace(".", "_")»_«iface.name» {
            «IF !oneWays.empty»
            OneWay:
            «ENDIF»
                «FOR o : oneWays SEPARATOR ","»
                «o»
                «ENDFOR»
            «IF !requestResponses.empty»
            RequestResponse:
            «ENDIF»
                «FOR o : requestResponses SEPARATOR ","»
                «o»
                «ENDFOR»
        }
        '''
    }

    /**
     * Generate types from operation parameters
     */
    private def generateOperationTypes(Operation operation) {
        operation.checkParameterTypes

        val asynchronousParameters = operation.parameters
            .filter[it.communicationType == CommunicationType.ASYNCHRONOUS]
            .map[(it as Parameter).generateTypeFromAsynchronousParameter]
        val types = '''
            «operation.generateTypeFromSynchronousParameters(ExchangePattern.IN)»
            «operation.generateTypeFromSynchronousParameters(ExchangePattern.OUT)»
            «FOR p : asynchronousParameters»
                «p»
            «ENDFOR»
        '''

        if (!types.empty)
            '''
            ///@operationTypes(«operation.buildQualifiedName(".")»)
            «types»
            '''
        else
            ""
    }

    /**
     * Check the parameter types of the given operation prior to their generation
     */
    private def checkParameterTypes(Operation operation) {
        operation.parameters
            .filter[it.importedType !== null]
            .forEach[
                val importAlias = it.importedType.import.name
                val typeName = (it.importedType.type as ComplexType).buildQualifiedName(".")
                if (!importAlias.isTypeAvailable(typeName))
                    throw new InvalidParameterTypeException(operation, importAlias, typeName)
            ]
    }

    /**
     * Check if a type with the given name exists in the domain model with the given import alias. A
     * type does not exist when there is no mapping of LEMMA to a Jolie type to be realized by the
     * domain generation. For example, LEMMA data structures with the Specification feature may only
     * comprise operations so that no (empty) Jolie type will be generated but only an interface.
     */
    private def isTypeAvailable(String importAlias, String typeName) {
        return availableComplexTypes.containsKey(importAlias) &&
            availableComplexTypes.get(importAlias).contains(typeName)
    }

    /**
     * Specialized exception to communicate the absence of a Jolie mapping for a LEMMA type
     */
    private static class InvalidParameterTypeException extends Exception {
        new(Operation operation, String importAlias, String typeName) {
            super('''Invalid type «importAlias»::«typeName» for operation ''' +
                '''«operation.buildQualifiedName(".")»: Likely there exists no mapping for ''' +
                "the LEMMA type into a Jolie type so that it will not be available in the " +
                "generated program")
        }
    }

    /**
     * Generate a type for an asynchronous operation parameter
     */
    private def generateTypeFromAsynchronousParameter(Parameter parameter) {
        parameter.operation.checkNoInout

        val typeName = parameterTypesManager.registerTypeForAsynchronousParameter(parameter)
        '''
        type «typeName» {
            «IF parameter.exchangePattern == ExchangePattern.IN»token : Token«ENDIF»
            «parameter.generateField»
        }'''
    }

    /**
     * Throw an UnsupportedExchangePattern in case the given parameter has the INOUT pattern
     */
    private def checkNoInout(Operation operation) {
        if (operation.parameters.exists[it.exchangePattern == ExchangePattern.INOUT])
            throw new UnsupportedExchangePattern(operation, ExchangePattern.INOUT)
    }

    /**
     * Specialized exception to communicate the absence of a Jolie mapping for a LEMMA type
     */
    private static class UnsupportedExchangePattern extends Exception {
        new(Operation operation, ExchangePattern pattern) {
            super('''Parameters of operation «operation.buildQualifiedName(".")» have ''' +
                '''unsupported exchange pattern «pattern.literal.toLowerCase»''')
        }
    }

    /**
     * Generate the type field for the given parameter
     */
    private def generateField(Parameter parameter) {
        val parameterType = parameter.effectiveType
        val parameterTypeName = if (parameterType instanceof PrimitiveType)
                DomainGenerationModule.generatePrimitiveType(parameterType.typeName)
            else
                (parameterType as ComplexType).name

        '''«parameter.name» : «parameterTypeName»'''
    }

    /**
     * Generate a type for all synchronous parameters of the given operation with the given exchange
     * pattern
     */
    private def generateTypeFromSynchronousParameters(Operation operation,
        ExchangePattern pattern) {
        operation.checkNoInout

        val parameters = operation.parameters.filter[
                it.communicationType == CommunicationType.SYNCHRONOUS &&
                it.exchangePattern == pattern
            ]
        if (parameters.empty)
            return ""

        val typeName = parameterTypesManager.registerTypeForSynchronousParameters(operation,
            pattern)
        val parameterTypes = parameters.map[(it as Parameter).generateField]
        '''
        type «typeName» {
            «FOR t : parameterTypes»
                «t»
            «ENDFOR»
        }'''
    }

    /**
     * Generate Jolie operations from the given LEMMA operation
     */
    private def generateOperations(Operation operation) {
        val oneWays = <String>newArrayList
        val requestResponses = <String>newArrayList

        /* Handle synchronous incoming parameters */
        val syncInType = parameterTypesManager.getTypeForSynchronousParameters(operation,
            ExchangePattern.IN) ?: "void"
        // If the operation has asynchronous parameters, we need a Jolie operation to synchronously
        // start the operation and receive a token for asynchronous communication
        if (operation.hasAsynchronousParameters)
            requestResponses.add('''«operation.name»_in(«syncInType»)(Token)''')

        /* Handle asynchronous parameters */
        operation.parameters.filter[it.communicationType == CommunicationType.ASYNCHRONOUS].forEach[
            val asyncType = parameterTypesManager.getTypeForAsynchronousParameter(it)
            switch(it.exchangePattern) {
                // Incoming asynchronous parameters have one-way operations to send data to
                // services. Note that the generated parameter type comprises a token field to pass
                // the token for the asynchronous communication to the service.
                case IN:
                    oneWays.add(
                        '''«operation.name»_«it.exchangePattern.literal.toLowerCase»_«it.name»''' +
                        '''(«asyncType»)'''
                    )
                // Outgoing asynchronous parameters have request-response operations to receive data
                // from services by passing them the token for the asynchronous communication.
                case OUT:
                    requestResponses.add(
                        '''«operation.name»_«it.exchangePattern.literal.toLowerCase»_«it.name»''' +
                        '''(Token)(«asyncType»)'''
                    )
                case INOUT:
                    throw new IllegalArgumentException("Operation generation for " +
                        '''«it.exchangePattern» exchange patterns is not supported''')
            }
        ]

        /* Handle synchronous outgoing parameters */
        val syncOutType = parameterTypesManager.getTypeForSynchronousParameters(operation,
            ExchangePattern.OUT)

        if (operation.hasAsynchronousParameters) {
            // If the operation has synchronous outgoing parameters (and thus a corresponding type),
            // we need a Jolie operation to synchronously retrieve the data by the token assigned to
            // the previously conducted asynchronous work.
            if (syncOutType !== null)
                requestResponses.add('''«operation.name»_out(Token)(«syncOutType»)''')
        } else if (syncOutType !== null)
            // No asynchronous parameters, so the generation must produce one single
            // request-response operation for all incoming and outgoing synchronous parameters
            requestResponses.add('''«operation.name»(«syncInType»)(«syncOutType»)''')
        else
            // No asynchronous parameters and no synchronous outgoing parameter, so the generation
            // must produce one single one-way operation for all incoming synchronous parameters
            oneWays.add('''«operation.name»(«syncInType»)''')

        return oneWays -> requestResponses
    }

    /**
     * Helper to check if the given operation has asynchronous parameters
     */
    private def hasAsynchronousParameters(Operation operation) {
        return operation.parameters.exists[it.communicationType == CommunicationType.ASYNCHRONOUS]
    }
}