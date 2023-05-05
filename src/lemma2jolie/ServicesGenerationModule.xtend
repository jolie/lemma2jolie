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
import java.nio.charset.StandardCharsets
import de.fhdo.lemma.service.Interface
import de.fhdo.lemma.service.Operation
import de.fhdo.lemma.technology.ExchangePattern
import de.fhdo.lemma.data.ComplexType
import de.fhdo.lemma.data.PrimitiveType
import de.fhdo.lemma.technology.CommunicationType
import java.util.Set
import de.fhdo.lemma.service.Parameter
import static lemma2jolie.DomainGenerationModule.OWN_FILES_FOR_CONTEXTS_ARGUMENT
import java.util.Objects
import org.eclipse.xtend.lib.annotations.Accessors
import de.fhdo.lemma.service.Microservice
import de.fhdo.lemma.model_processing.phases.PhaseException
import de.fhdo.lemma.data.Context
import java.util.LinkedHashSet

/**
 * LEMMA code generation module to derive Jolie code from a LEMMA service model. The service model
 * must be passed as a source model to the generator using the "-s" commandline option. Furthermore,
 * the module must be explicitly executed using the "--invoke_only_specified_modules services"
 * commandline argument. The resulting Jolie program will have the same name as the passed service
 * model but with the ".ol" extension.
 */
@CodeGenerationModule(name="services", modelKinds=ModelKind.SOURCE)
class ServicesGenerationModule extends AbstractCodeGenerationModule {
    val serviceTargetFiles = <String, GeneratedContextFile>newHashMap
    val availableComplexTypes = <String, Set<String>>newHashMap
    var ParameterTypesManager parameterTypesManager
    var boolean ownFilesForContexts

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
        serviceTargetFiles.clear
        availableComplexTypes.clear
        parameterTypesManager = new ParameterTypesManager()
        ownFilesForContexts = moduleArguments.exists[OWN_FILES_FOR_CONTEXTS_ARGUMENT.contains(it)]

        val model = resource.contents.get(0) as ServiceModel
        val generatedContextFiles = generateDomainContextFiles(model)

        if (ownFilesForContexts)
            serviceTargetFiles.putAll(identifyServiceTargetFiles(model, generatedContextFiles))

        model.microservices
            .map[it.interfaces]
            .flatten
            .forEach[
                var String exception = null
                try {
                    it.microservice
                        .getTargetFile(generatedContextFiles)
                        .addContent((it as Interface).generateInterface.toString)
                } catch (InvalidParameterTypeException ex) {
                    exception = ex.message
                } catch (UnsupportedExchangePattern ex) {
                    exception = ex.message
                }

                if (exception !== null)
                    throw new PhaseException(exception, true)
            ]

        return withCharset(generatedContextFiles.toMap([it.filepath], [it.generatedContent]),
            StandardCharsets.UTF_8.name)
    }

    /**
     * Generate Jolie types and interfaces for all LEMMA domain models imported by the given LEMMA
     * service model. This generation step ensures that the Jolie code produced for LEMMA
     * microservices can access these types.
     */
    private def generateDomainContextFiles(ServiceModel serviceModel) {
        val generatedContextsPerFile = <GeneratedContextFile>newLinkedHashSet

        serviceModel.imports.filter[it.importType == ImportType.DATATYPES].forEach[
            // Load the imported domain model
            val importedDomainModelUri = LemmaUtils.absoluteFileUriFromResourceBase(it.importURI,
                serviceModel.eResource)
            val importedDomainModelPath = LemmaUtils.removeFileUri(importedDomainModelUri)
            val domainModel = loadDomainModel(importedDomainModelPath)

            // Generate the domain model types per bounded context using the domain generation
            // module
            domainModel.contexts.forEach[context |
                val generationModule = new DomainGenerationModule()
                generationModule.ownFilesForContexts = ownFilesForContexts
                val generatedContextFileContent = generationModule.generateContextFile(
                        context as Context,
                        targetFolder,
                        modelFile
                    )
                val generatedFile = generatedContextFileContent.key
                val generatedContent = generatedContextFileContent.value
                // Determine the file for the generated context-specific types, which is either a
                // dedicated file in case the user instrumented the generator accordingly or the#
                // file that gathers all generated types of all bounded contexts
                var generatedContextFile = if (!ownFilesForContexts)
                        generatedContextsPerFile.findFirst[it.representsAllContexts]
                    else
                        null

                if (generatedContextFile === null) {
                    val contextName = ownFilesForContexts ? context.name : null
                    generatedContextFile = new GeneratedContextFile(contextName, generatedFile)
                    generatedContextFile.representsAllContexts = !ownFilesForContexts
                    generatedContextsPerFile.add(generatedContextFile)
                }

                generatedContextFile.addContent(generatedContent)

                val generatedComplexTypes = generationModule.generatedComplexTypesNames
                if (availableComplexTypes.containsKey(context.name))
                    throw new PhaseException('''Duplicate context «context.name» in different ''' +
                        "domain models detected", true)
                availableComplexTypes.put(context.name, generatedComplexTypes)
            ]
        ]

        return generatedContextsPerFile
    }

    /**
     * Helper class to cluster information about generated files, the bounded contexts they cover,
     * their paths, and content
     */
    private static class GeneratedContextFile {
        @Accessors(PUBLIC_GETTER)
        val String contextName
        @Accessors(PUBLIC_GETTER)
        val String filepath
        @Accessors(PUBLIC_GETTER)
        var String generatedContent = ""
        /**
         * Flag to indicate that this file gathers the generated Jolie code for all bounded
         * contexts. That is, there will be no context-specific generated files but only one
         * comprising all generated code.
         */
        @Accessors
        var boolean representsAllContexts

        /**
         * Constructor
         */
        new(String contextName, String filepath) {
            this.contextName = contextName
            this.filepath = filepath
        }

        /**
         * Add generated content to the file
         */
        def addContent(String content) {
            generatedContent += if (generatedContent.empty)
                    content
                else
                    "\n" + content
        }

        /**
         * Equality based on the name of the covered bounded context
         */
        override equals(Object other) {
            return (other == this) ||
                (other instanceof GeneratedContextFile) &&
                (other as GeneratedContextFile).contextName == contextName
        }

        /**
         * Hash code based on the name of the covered bounded context
         */
        override hashCode() {
            return Objects.hashCode(contextName)
        }
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
     * Identify context-specific generation target file from the given set of files for each
     * microservice in the given service model. In case the identification is not unambiguously
     * possible, this method with instruct the generator to stop by throwing a corresponding
     * PhaseException.
     */
    private def identifyServiceTargetFiles(ServiceModel model,
        LinkedHashSet<GeneratedContextFile> generatedContextFiles) {
        return model.microservices.toMap(
            [it.buildQualifiedName(".")],

            [
                val contexts = it.determineContexts

                if (contexts.size == 1)
                    generatedContextFiles.findFirst[it.contextName == contexts.get(0)]
                else if (contexts.size > 1)
                    throw new PhaseException('''Microservice «it.buildQualifiedName(".")» ''' +
                        '''operates on more than one bounded context: «contexts.join(", ")». ''' +
                        "Unambiguous identification of context-specific generation target file " +
                        "not possible.", true)
                else
                    throw new PhaseException('''Microservice «it.buildQualifiedName(".")» does ''' +
                        "not operate on a bounded context which is necessary for the generation " +
                        "of contexts in their own files", true)
            ]
        )
    }

    /**
     * Determine all bounded contexts on which the given microservice operators. These contexts
     * correspond to the bounded contexts of the service's complex operation parameter types.
     */
    private def determineContexts(Microservice microservice) {
        return microservice.containedOperations
            .map[it.parameters]
            .flatten
            .map[it.effectiveType]
            .filter[it instanceof ComplexType]
            .map[(it as ComplexType).context.name]
            .toSet
    }

    /**
     * Get the target file for the Jolie code of the given microservice. The target file is either
     * context-specific (in case the user instructed the generator to have context-specific files)
     * or otherwise the single file that gathers all Jolie types from all bounded contexts.
     */
    private def getTargetFile(Microservice microservice,
        LinkedHashSet<GeneratedContextFile> generatedContextFiles) {
        return if (ownFilesForContexts)
                serviceTargetFiles.get(microservice.buildQualifiedName("."))
            else
                generatedContextFiles.findFirst[it.representsAllContexts]
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
                val type = it.importedType.type as ComplexType
                val contextName = type.context.name
                val typeName = type.buildQualifiedName(".")
                if (!contextName.isTypeAvailable(typeName))
                    throw new InvalidParameterTypeException(operation, typeName)
            ]
    }

    /**
     * Check if a type with the given name exists in the domain model with the given context. A type
     * does not exist when there is no mapping of LEMMA to a Jolie type to be realized by the domain
     * generation. For example, LEMMA data structures with the Specification feature may only
     * comprise operations so that no (empty) Jolie type will be generated but only an interface.
     */
    private def isTypeAvailable(String contextName, String typeName) {
        return availableComplexTypes.containsKey(contextName) &&
            availableComplexTypes.get(contextName).contains(typeName)
    }

    /**
     * Specialized exception to communicate the absence of a Jolie mapping for a LEMMA type
     */
    private static class InvalidParameterTypeException extends Exception {
        new(Operation operation, String typeName) {
            super('''Invalid type «typeName» for operation «operation.buildQualifiedName(".")»:''' +
                " Likely there exists no mapping for the LEMMA type into a Jolie type so that it " +
                "will not be available in the generated program")
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
        var syncOutType = parameterTypesManager.getTypeForSynchronousParameters(operation,
            ExchangePattern.OUT)

        if (operation.hasAsynchronousParameters) {
            // If the operation has synchronous outgoing parameters (and thus a corresponding type),
            // we need a Jolie operation to synchronously retrieve the data by the token assigned to
            // the previously conducted asynchronous work.
            if (syncOutType !== null)
                requestResponses.add('''«operation.name»_out(Token)(«syncOutType»)''')
        } else {
            // No asynchronous parameters, so the generation must produce one single
            // request-response operation for all incoming and outgoing synchronous parameters
            if (syncOutType === null)
                syncOutType = "void"
            requestResponses.add('''«operation.name»(«syncInType»)(«syncOutType»)''')
        }

        return oneWays -> requestResponses
    }

    /**
     * Helper to check if the given operation has asynchronous parameters
     */
    private def hasAsynchronousParameters(Operation operation) {
        return operation.parameters.exists[it.communicationType == CommunicationType.ASYNCHRONOUS]
    }
}