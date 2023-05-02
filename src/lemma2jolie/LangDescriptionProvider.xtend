package lemma2jolie

import de.fhdo.lemma.model_processing.annotations.LanguageDescriptionProvider
import de.fhdo.lemma.model_processing.languages.LanguageDescriptionProviderI
import de.fhdo.lemma.model_processing.languages.XtextLanguageDescription
import de.fhdo.lemma.data.DataPackage
import de.fhdo.lemma.data.DataDslStandaloneSetup
import de.fhdo.lemma.service.ServicePackage
import de.fhdo.lemma.ServiceDslStandaloneSetup

@LanguageDescriptionProvider
class LangDescriptionProvider implements LanguageDescriptionProviderI {
    override getLanguageDescription(boolean forLanguageNamespace, boolean forFileExtension,
        String languageNamespaceOrFileExtension) {
        return switch (languageNamespaceOrFileExtension) {
            case "data":
                new XtextLanguageDescription(DataPackage.eINSTANCE, new DataDslStandaloneSetup)
            case "services":
                new XtextLanguageDescription(ServicePackage.eINSTANCE,
                    new ServiceDslStandaloneSetup)
            default: null
        }
    }
}