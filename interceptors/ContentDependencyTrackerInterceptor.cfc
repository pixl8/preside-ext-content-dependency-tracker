component {

	property name="contentDependencyTrackerService" inject="delayedInjector:contentDependencyTrackerService";
	property name="presideObjectService"            inject="delayedInjector:presideObjectService";

	public void function configure() {}

	public void function postInsertObjectData( event, interceptData ) {

		if ( _skip( interceptData ) ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var id         = len( trim( interceptData.newId ?: "" ) ) ? trim( interceptData.newId ) : trim( interceptData.data.id ?: "" );

		if ( len( id ) ) {
			contentDependencyTrackerService.createContentObject( objectName=objectName, id=id );
		}
	}

	public void function postUpdateObjectData( event, interceptData ) {

		if ( _skip( interceptData ) ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var id         = Len( Trim( interceptData.id ?: "" ) ) ? trim( interceptData.id ) : trim( interceptData.data.id ?: "" );

		if ( len( id ) ) {
			contentDependencyTrackerService.flagContentObjectForScanning( objectName=objectName, id=id );
		}
	}

	public void function preDeleteObjectData( event, interceptData ) {

		if ( _skip( interceptData ) ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var idField    = presideObjectService.getIdField( objectName=objectName );

		try {
			var records = presideObjectService.selectData( argumentCollection=arguments.interceptData, selectFields=[ idField ] );

			if ( records.recordCount ) {
				var ids = queryColumnData( records, idField );
				contentDependencyTrackerService.flagContentObjectsDeleted( objectName=objectName, ids=ids );
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

		var renderedView = trim( renderViewlet( event="admin.datamanager.tracked_content_object.linkToTracker", args=interceptData ) );
		
		if ( len( renderedView ) ) {
			interceptData.renderedLayout = ( interceptData.renderedLayout ?: "" ).reReplaceNoCase( '<ul class="breadcrumb">((.|\n)*?)</ul>', '<ul class="breadcrumb">\1</ul>#chr(10)##renderedView#' );
		}
	}

	private boolean function _skip( interceptData ) {

		if ( _skipTrivialInterceptors( interceptData ) || _skipDependencyTracking( interceptData ) || !contentDependencyTrackerService.isEnabled() || !contentDependencyTrackerService.isSingleRecordScanningEnabled() ) {
			return true;
		}

		return !contentDependencyTrackerService.isTrackingEnabledObject( objectName=interceptData.objectName ?: "" );
	}

	private boolean function _skipTrivialInterceptors( interceptData ) {
		return IsBoolean( interceptData.skipTrivialInterceptors ?: "" ) && interceptData.skipTrivialInterceptors;
	}

	private boolean function _skipDependencyTracking( interceptData ) {
		return IsBoolean( interceptData.skipDependencyTracking ?: "" ) && interceptData.skipDependencyTracking;
	}
}