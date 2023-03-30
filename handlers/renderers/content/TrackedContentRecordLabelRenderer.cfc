component {

	property name="configService" inject="contentDependencyTrackerConfigurationService";

	private string function default( event, rc, prc, args={} ) {
		var label      = args.data          ?: "";
		var record     = args.record        ?: {};
		var objectName = record.object_name ?: "";

		return configService.renderTrackedContentRecordLabel( objectName=objectName, label=label );
	}
}