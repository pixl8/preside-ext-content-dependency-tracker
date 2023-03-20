component {

	property name="contentDependencyTrackerService" inject="contentDependencyTrackerService";

	private array function _selectFields( event, rc, prc ) {
		return [
			  "label"
			, "content_type"
		];
	}

	private string function _renderLabel( event, rc, prc ) {
		var label       = arguments.label        ?: "";
		var contentType = arguments.content_type ?: "";

		return contentDependencyTrackerService.renderTrackedContentObjectLabel( contentType=contentType, label=label );
	}
}