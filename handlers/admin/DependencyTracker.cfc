component {

	property name="trackerService" inject="contentDependencyTrackerService";
	property name="configService"  inject="contentDependencyTrackerConfigurationService";

	public string function linkToTracker( event, rc, prc ) {

		if ( !configService.isEnabled() ) {
			return "";
		}

		var contentRecord = trackerService.detectContentRecordByRequestContext( rc );

		if ( !isEmpty( contentRecord ) ) {
			return renderView( view=configService.getLinkToTrackerView(), args=contentRecord );
		}

		return "";
	}
}