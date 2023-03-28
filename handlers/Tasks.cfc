component {

	property name="contentDependencyTrackerService" inject="contentDependencyTrackerService";

	/**
	 * Full scanning of content records to be tracked
	 *
	 * @displayName      [1] Scan all content record dependencies
	 * @displayGroup     Content
	 * @exclusivityGroup ContentDependencyTracker
	 * @schedule         0 42 2 * * *
	 * @priority         10
	 * @timeout          7200
	 *
	 */
	private boolean function fullScanContentDependencies( event, rc, prc, logger ) {
		return contentDependencyTrackerService.scanContentDependencies( full=true, logger=arguments.logger );
	}

	/**
	 * Delta scanning of content records to be tracked - only those marked as scanning-required
	 *
	 * @displayName      [2] Scan changed content records for dependencies
	 * @displayGroup     Content
	 * @exclusivityGroup ContentDependencyTracker
	 * @schedule         0 *\/5 * * * *
	 * @priority         10
	 * @timeout          7200
	 *
	 */
	private boolean function scanFlaggedContentDependencies( event, rc, prc, logger ) {
		return contentDependencyTrackerService.scanContentDependencies( full=false, logger=arguments.logger );
	}
}