package lemma2jolie

import de.fhdo.lemma.model_processing.annotations.CodeGenerationModule
import de.fhdo.lemma.model_processing.builtin_phases.code_generation.AbstractCodeGenerationModule
import de.fhdo.lemma.data.DataPackage
import de.fhdo.lemma.data.DataModel
import de.fhdo.lemma.data.Context
import de.fhdo.lemma.data.DataStructure
import de.fhdo.lemma.data.CollectionType
import de.fhdo.lemma.data.Enumeration
import de.fhdo.lemma.data.DataField
import de.fhdo.lemma.data.PrimitiveTypeConstants
import de.fhdo.lemma.data.DataOperation
import java.io.File
import java.nio.charset.StandardCharsets
import de.fhdo.lemma.model_processing.phases.ModelKind
import org.eclipse.xtend.lib.annotations.Accessors
import java.util.List
import org.apache.commons.io.FilenameUtils

/**
 * LEMMA code generation module to derive Jolie code from a LEMMA domain model. The domain model
 * must be passed as a source model to the generator using the "-s" commandline option. Furthermore,
 * the module must be explicitly executed using the "--invoke_only_specified_modules domain"
 * commandline argument. The resulting Jolie program will have the same name as the passed domain
 * model but with the ".ol" extension.
 */
@CodeGenerationModule(name="domain", modelKinds=ModelKind.SOURCE)
class DomainGenerationModule extends AbstractCodeGenerationModule {
    val generatedComplexTypesNames = <String>newHashSet
    val structuresWithGeneratedFeatures = <String>newHashSet

    /**
     * Return language namespace for parsing LEMMA domain models
     */
    override getLanguageNamespace() {
        return DataPackage.eNS_URI
    }

    /**
     * Execution logic of the module
     */
    override execute(String[] phaseArguments, String[] moduleArguments) {
        structuresWithGeneratedFeatures.clear

        val model = resource.contents.get(0) as DataModel
        val generatedContexts = model.contexts.map[it.generateContext]

        val baseFileName = FilenameUtils.getBaseName(modelFile)
        val targetFile = '''«targetFolder»«File.separator»«baseFileName».ol'''
        return withCharset(#{targetFile -> generatedContexts.join("\n")},
            StandardCharsets.UTF_8.name)
    }

    /**
     * Encode a bounded context contained in a LEMMA domain model in Jolie
     */
    def generateContext(Context context) {
        generatedComplexTypesNames.clear

        '''
        ///@beginCtx(«context.name»)
        «context.complexTypes.map[it.generateComplexType].join("\n")»
        ///@endCtx
        '''
    }

    /**
     * Get all generated complex types that were derived during an execution of the module either
     * from a call to execute() or generateContext()
     */
    def getGeneratedComplexTypesNames() {
        return generatedComplexTypesNames.immutableCopy
    }

    /**
     * Encode a LEMMA data structure as a Jolie type and, in case the structure specifies operation
     * signatures, as a Jolie interface
     */
    private def dispatch generateComplexType(DataStructure structure) {
        '''
        «structure.generateType»
        «IF !structure.operations.empty»
            «structure.generateInterface»
        «ENDIF»
        '''
    }

    /**
     * Encode a LEMMA data structure as a Jolie type
     */
    private def generateType(DataStructure structure) {
        if (!structure.requiresGeneratedType)
            return ""

        // Tell the generator that we will encode the features of this structure
        structuresWithGeneratedFeatures.add(structure.buildQualifiedName("."))

        generatedComplexTypesNames.add(structure.buildQualifiedName("."))

        '''
        «structure.features.map[it.literal].generateFeatures»
        «generateTypeFromFields(structure.name, structure.dataFields)»
        '''
    }

    /**
     * Check if a data structure requires a type to get generated
     */
    private def requiresGeneratedType(DataStructure structure) {
        // Prevent empty types
        return !structure.dataFields.empty
    }

    /**
     * Encode a list of LEMMA features as Jolie comments
     */
    private def generateFeatures(List<String> featureLiterals) {
        '''
        «FOR l : featureLiterals»
            ///@«l.generateFeature»
        «ENDFOR»
        '''
    }

    /**
     * Generate a Jolie type from a list of LEMMA data fields
     */
    private def generateTypeFromFields(String name, List<DataField> fields) {
        '''
        type «name» {
            «FOR f : fields»
            «f.generateDataField»
            «ENDFOR»
        }
        '''
    }

    /**
     * Encode a LEMMA data field as a Jolie field
     */
    private def generateDataField(DataField field) {
        val typeName = field.complexType?.name ?: field.primitiveType.typeName.generatePrimitiveType

        '''
        «field.features.map[it.literal].generateFeatures»
        «field.name»: «typeName»
        '''
    }

    /**
     * Map a LEMMA feature literal to a lower-camel-case string
     */
    private def generateFeature(String featureLiteral) {
        val nameParts = featureLiteral.split("_").map[it.toLowerCase.toFirstUpper]
        return nameParts.join().toFirstLower
    }

    /**
     * Encode a LEMMA primitive type as a Jolie type
     */
    static def generatePrimitiveType(String typeName) {
        return switch (typeName) {
            case PrimitiveTypeConstants.BOOLEAN.literal: "bool"
            case PrimitiveTypeConstants.BYTE.literal,
                case PrimitiveTypeConstants.INTEGER.literal,
                case PrimitiveTypeConstants.SHORT.literal: "int"
            case PrimitiveTypeConstants.CHARACTER.literal,
                case PrimitiveTypeConstants.DATE.literal,
                case PrimitiveTypeConstants.STRING.literal: "string"
            case PrimitiveTypeConstants.LONG.literal: "long"
            case PrimitiveTypeConstants.FLOAT.literal,
                case PrimitiveTypeConstants.DOUBLE.literal: "double"
            case PrimitiveTypeConstants.UNSPECIFIED.literal: "undefined"
            default: throw new IllegalArgumentException('''Unsupported primitive type «typeName»''')
        }
    }

    /**
     * Encode the operations of a LEMMA data structure as a Jolie interface
     */
    private def generateInterface(DataStructure structure) {
        '''
        ««« In case the structure contains only operations, make sure that we encode the features
        ««« of the structure before the operation parameter types. In case the structure also
        ««« contains, the generateType(DataStructure) encoding function will already have taken care
        ««« of the features.
        «IF !structuresWithGeneratedFeatures.contains(structure.buildQualifiedName("."))»
            «structure.features.map[it.literal].generateFeatures»
        «ENDIF»
        «FOR o : structure.operations»
            «o.generateOperationParameterType»
        «ENDFOR»
        interface «structure.name»_interface {
            RequestResponse:
                «FOR o : structure.operations SEPARATOR ","»
                    «o.generateOperation»
                «ENDFOR»
        }
        '''
    }

    /**
     * Generate the type of a parameter in a Jolie interface for a given LEMMA domain operation
     */
    private def generateOperationParameterType(DataOperation operation) {
        '''
        type «operation.parameterTypeName» {
            «FOR p : operation.parameters»
                «p.name»: «p.complexType?.name ?: p.primitiveType.typeName.generatePrimitiveType»
            «ENDFOR»
            «IF operation.dataStructure.requiresGeneratedType»
                self?: «operation.dataStructure.name»
            «ENDIF»
        }
        '''
    }

    /**
     * Generate the name of a parameter type in a Jolie interface for a given LEMMA domain operation
     */
    private def parameterTypeName(DataOperation operation) {
        '''«operation.name»_type'''
    }

    /**
     * Encode a LEMMA domain operation in Jolie
     */
    private def generateOperation(DataOperation operation) {
        return if (operation.hasNoReturnType)
                operation.generateProcedure
            else
                operation.generateFunction
    }

    /**
     * Encode a LEMMA procedure as a Jolie operation with a void return type
     */
    private def generateProcedure(DataOperation operation) {
        '''
        «operation.features.map[it.literal].generateFeatures»
        «operation.name»(«operation.parameterTypeName»)(void)
        '''
    }

    /**
     * Encode a LEMMA function as a Jolie operation with a corresponding return type
     */
    private def generateFunction(DataOperation operation) {
        val returnTypeName = operation.complexReturnType?.name
            ?: operation.primitiveReturnType.typeName.generatePrimitiveType

        '''
        «operation.features.map[it.literal].generateFeatures»
        «operation.name»(«operation.parameterTypeName»)(«returnTypeName»)
        '''
    }

    /**
     * Encode a LEMMA collection type as a Jolie type
     */
    private def dispatch generateComplexType(CollectionType collectionType) {
        val fieldTypeInfo = collectionType.generateFieldType

        generatedComplexTypesNames.add(collectionType.buildQualifiedName("."))

        '''
        «fieldTypeInfo.generatedFieldType»
        «collectionType.features.map[it.literal].generateFeatures»
        type «collectionType.name» {
            «fieldTypeInfo.fieldName»*: «fieldTypeInfo.fieldTypeName»
        }
        '''
    }

    /**
     * Derive the type of the field in a Jolie type being derived from a LEMMA collection type
     */
    private def generateFieldType(CollectionType collectionType) {
        return
        // LEMMA collection type comprises a single primitive type, which will become the type of
        // the field "f" in the corresponding Jolie list type.
        if (collectionType.primitiveType !== null)
            new FieldTypeInfo("f", collectionType.primitiveType.typeName.generatePrimitiveType)

        // LEMMA collection type comprises a single data field. The name of the field in the encoded
        // Jolie list type will correspond to the name of the LEMMA data field. The type of the
        // Jolie field will be the encoded Jolie type of the LEMMA data field's type.
        else if (collectionType.dataFields.size == 1) {
            val field = collectionType.dataFields.get(0)
            val fieldTypeName = field.primitiveType?.typeName?.generatePrimitiveType
                ?: field.complexType.name
            new FieldTypeInfo(field.name, fieldTypeName)

        // LEMMA collection type comprises more than one field (empty collection types are forbidden
        // per the grammar of LEMMA's domain modeling language). Semantically, the fields form a
        // structured type so that each entry in the collection will have a structure consisting of
        // all fields of the collection type. To encode this circumstance in Jolie, we first produce
        // a Jolie type that maps the structure of the LEMMA data fields and then use it as the type
        // for the generated Jolie field called "f".
        } else {
            val fieldTypeName = '''«collectionType.name»_structure'''
            new FieldTypeInfo("f", fieldTypeName,
                generateTypeFromFields(fieldTypeName, collectionType.dataFields))
        }
    }

    /**
     * Gather encoding information about LEMMA collection fields
     */
    private static class FieldTypeInfo {
        @Accessors(PUBLIC_GETTER)
        val String fieldName
        @Accessors(PUBLIC_GETTER)
        val String fieldTypeName
        @Accessors(PUBLIC_GETTER)
        val CharSequence generatedFieldType

        new (String fieldName, String fieldTypeName) {
            this(fieldName, fieldTypeName, "")
        }

        new (String fieldName, String fieldTypeName, CharSequence generatedFieldType) {
            this.fieldName = fieldName
            this.fieldTypeName = fieldTypeName
            this.generatedFieldType = generatedFieldType
        }
    }

    /**
     * Encode a LEMMA enumeration as a Jolie type
     */
    private def dispatch generateComplexType(Enumeration enumeration) {
        val literalList = enumeration.fields.map['''"«it.name»"'''].join(", ")

        generatedComplexTypesNames.add(enumeration.buildQualifiedName("."))

        '''
        «enumeration.features.map[it.literal].generateFeatures»
        type «enumeration.name» {
            literal: string(enum([«literalList»]))
        }
        '''
    }
}