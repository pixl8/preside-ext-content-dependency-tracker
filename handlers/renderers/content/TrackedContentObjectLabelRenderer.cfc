component {

	property name="contentDependencyTrackerService" inject="contentDependencyTrackerService";

	private string function default( event, rc, prc, args={} ) {
		var label       = args.data           ?: "";
		var record      = args.record         ?: {};
		var contentType = record.content_type ?: "";

		return contentDependencyTrackerService.renderTrackedContentObjectLabel( contentType=contentType, label=label );
	}
}