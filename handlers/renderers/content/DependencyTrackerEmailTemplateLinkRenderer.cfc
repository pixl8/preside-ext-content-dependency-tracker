component {

	property name="systemEmailTemplateService" inject="systemEmailTemplateService";

	private string function default( event, rc, prc, args={} ){
		var objectId = args.data ?: "";

		if ( systemEmailTemplateService.templateExists( objectId ) ) {
			return event.buildAdminLink( linkto="emailcenter.systemtemplates.template", queryString="template=#objectId#" );
		}

		return event.buildAdminLink( linkto="emailCenter.customTemplates.preview", queryString="id=#objectId#" );
	}
}