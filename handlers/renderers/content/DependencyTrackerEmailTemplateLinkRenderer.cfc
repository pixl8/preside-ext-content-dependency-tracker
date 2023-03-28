component {

	property name="systemEmailTemplateService" inject="systemEmailTemplateService";

	private string function default( event, rc, prc, args={} ){
		var recordId = args.data ?: "";

		if ( systemEmailTemplateService.templateExists( recordId ) ) {
			return event.buildAdminLink( linkto="emailcenter.systemtemplates.template", queryString="template=#recordId#" );
		}

		return event.buildAdminLink( linkto="emailCenter.customTemplates.preview", queryString="id=#recordId#" );
	}
}