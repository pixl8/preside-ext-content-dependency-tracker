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

	/**
	 * Manually trigger the caching of content record dependencies counts within the tracked content records
	 *
	 * @displayName      [3] Cache content record dependencies counts
	 * @displayGroup     Content
	 * @exclusivityGroup ContentDependencyTracker
	 * @schedule         disabled
	 * @priority         10
	 * @timeout          7200
	 *
	 */
	private boolean function cacheContentRecordDependencyCounts( event, rc, prc, logger ) {
		return contentDependencyTrackerService.cacheContentRecordDependencyCounts(logger=arguments.logger );
	}
}