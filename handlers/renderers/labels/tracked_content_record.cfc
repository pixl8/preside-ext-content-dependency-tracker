component {

	property name="configService" inject="contentDependencyTrackerConfigurationService";

	private array function _selectFields( event, rc, prc ) {
		return [
			  "label"
			, "object_name"
		];
	}

	private string function _renderLabel( event, rc, prc ) {
		var label      = arguments.label       ?: "";
		var objectName = arguments.object_name ?: "";

		return configService.renderTrackedContentRecordLabel( objectName=objectName, label=label );
	}
}