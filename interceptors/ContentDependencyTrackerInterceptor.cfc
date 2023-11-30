component {

	property name="trackerService"       inject="delayedInjector:contentDependencyTrackerService";
	property name="configService"        inject="delayedInjector:contentDependencyTrackerConfigurationService";
	property name="presideObjectService" inject="delayedInjector:presideObjectService";

	public void function configure() {}

	public void function postInsertObjectData( event, interceptData ) {

		if ( _skip( interceptData ) ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var id         = len( trim( interceptData.newId ?: "" ) ) ? trim( interceptData.newId ) : trim( interceptData.data.id ?: "" );

		if ( len( id ) ) {
			trackerService.createContentRecord( objectName=objectName, id=id );
		}
	}

	public void function postUpdateObjectData( event, interceptData ) {

		if ( _skip( interceptData ) ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var id         = Len( Trim( interceptData.id ?: "" ) ) ? trim( interceptData.id ) : trim( interceptData.data.id ?: "" );

		if ( len( id ) ) {
			trackerService.flagContentRecordForScanning( objectName=objectName, id=id );
		}
	}

	public void function preDeleteObjectData( event, interceptData ) {

		if ( _skip( interceptData ) ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var idField    = presideObjectService.getIdField( objectName=objectName );

		if ( !Len( idField ) ) {
			return;
		}

		try {
			var records = presideObjectService.selectData( argumentCollection=arguments.interceptData, selectFields=[ idField ] );

			if ( records.recordCount ) {
				var ids = queryColumnData( records, idField );
				trackerService.flagContentRecordsDeleted( objectName=objectName, ids=ids );
			}
		}
		catch ( any e ) {
			var message = e.message ?: "";
			var detail  = e.detail  ?: "";
			var type    = e.type    ?: "";

			if ( type == "database" && ( message contains "Unknown column" || detail contains "Unknown column" ) ) {
				return;
			} else {
				rethrow;
			}
		}
		return;
	}

	public void function postLayoutRender( event, interceptData={} ) {

		if ( !isFeatureEnabled( "globalLinkToDependencyTracker" ) ) {
			return;
		}

		var layout = trim( interceptData.layout ?: "" );
		
		if ( layout != "admin" ) {
			return;
		}

		var renderedView = trim( renderViewlet( event="admin.datamanager.tracked_content_record.linkToTracker", args=interceptData ) );
		
		if ( len( renderedView ) ) {
			interceptData.renderedLayout = ( interceptData.renderedLayout ?: "" ).reReplaceNoCase( '<div class="navbar-header pull-right" role="navigation">.*<ul class="nav ace-nav">', '<div class="navbar-header pull-right" role="navigation"><ul class="nav ace-nav">#renderedView#' );
		}
	}

	private boolean function _skip( interceptData ) {
		if ( _appIsStarting() || _skipTrivialInterceptors( interceptData ) || _skipDependencyTracking( interceptData ) || !configService.isEnabled() || !configService.isSingleRecordScanningEnabled() ) {
			return true;
		}

		return !configService.isTrackableObject( objectName=interceptData.objectName ?: "" );
	}

	private boolean function _skipTrivialInterceptors( interceptData ) {
		return IsBoolean( interceptData.skipTrivialInterceptors ?: "" ) && interceptData.skipTrivialInterceptors;
	}

	private boolean function _skipDependencyTracking( interceptData ) {
		return IsBoolean( interceptData.skipDependencyTracking ?: "" ) && interceptData.skipDependencyTracking;
	}

	private boolean function _appIsStarting( interceptData ) {
		return IsBoolean( request._isPresideReloadRequest ?: "" ) && request._isPresideReloadRequest;
	}
}