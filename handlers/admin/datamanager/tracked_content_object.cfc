component extends="app.extensions.preside-ext-better-view-record-screen.base.BetterDatamanagerBase" {

	property name="contentDependencyTrackerService" inject="ContentDependencyTrackerService";

	variables.infoCol1 = [ "content_type", "hidden", "orphaned" ];
	variables.infoCol2 = [ "content_id", "last_scanned", "requires_scanning" ];

	variables.tabs = [ "dependsOn", "dependentBy" ];

	private void function rootBreadcrumb( event, rc, prc, arg={} ) {
		// leaving this method empty removes the "Data Manager" within the bread crumb trail
		// resulting in "Home > Tracked Content Objects" as the root breadcrumb
	}

	private string function objectBreadcrumb() {
		event.addAdminBreadCrumb(
			  title = "Dependency Tracker"
			, link  = event.buildAdminLink( objectName="tracked_content_object" )
		);
	}

	private string function recordBreadcrumb() {
		var recordLabel = prc.recordLabel     ?: "";
		var recordId    = prc.recordId        ?: "";
		var record      = prc.record          ?: {};
		var contentType = record.content_type ?: "";

		event.addAdminBreadCrumb( 
			  title = renderContent( "objectName", contentType, [ "adminDatatable", "admin" ] ) & ": " & htmlEditFormat( recordLabel )
			, link  = event.buildAdminLink( objectName="tracked_content_object", recordId=recordId )
		);
	}

	private string function _infoCardContent_type( event, rc, prc, args={} ) {
		var record = args.record ?: {};

		return '<strong>#translateResource( "preside-objects.tracked_content_object:field.content_type.title" )#</strong>:&nbsp; #renderContent( "objectName", record.content_type, [ "adminDatatable", "admin" ] )#';
	}

	private string function _infoCardContent_id( event, rc, prc, args={} ) {
		var record = args.record ?: {};

		return '<strong>#translateResource( "preside-objects.tracked_content_object:field.content_id.title" )#</strong>:&nbsp; #record.content_id#';
	}

	private string function _infoCardLast_scanned( event, rc, prc, args={} ) {
		var record = args.record ?: {};

		return '<strong>#translateResource( "preside-objects.tracked_content_object:field.last_scanned.title" )#</strong>:&nbsp; #dateTimeFormat( record.last_scanned, "yyyy-mm-dd HH:mm:ss" )#';
	}

	private string function _infoCardOrphaned( event, rc, prc, args={} ) {
		var record = args.record ?: {};
		var orphaned = isBoolean( record.orphaned ?: "" ) && record.orphaned;

		return orphaned ? '<span class="badge badge-important">#translateResource( "preside-objects.tracked_content_object:field.orphaned.title" )#</span>' : '';
	}

	private string function _infoCardHidden( event, rc, prc, args={} ) {
		var record = args.record ?: {};
		var hidden = isBoolean( record.hidden ?: "" ) && record.hidden;

		return hidden ? '<span class="badge">#translateResource( "preside-objects.tracked_content_object:field.hidden.title" )#</span>' : '';
	}

	private string function _infoCardRequires_scanning( event, rc, prc, args={} ) {
		var record = args.record ?: {};
		var requiresScanning = isBoolean( record.requires_scanning ?: "" ) && record.requires_scanning;

		return requiresScanning ? '<span class="badge badge-warning">#translateResource( "preside-objects.tracked_content_object:field.requires_scanning.title" )#</span>' : '';
	}

	private string function _dependsOnTab( event, rc, prc, args={} ) {
		return objectDataTable(
			  objectName = "tracked_content_object_dependency"
			, args       = {
				  useMultiActions  = false
				, allowDataExport  = false
				, clickableRows    = true
				, gridFields       = [ "dependent_content_object_type", "dependent_content_object", "content_object_field", "soft_or_fk", "dependent_content_object_orphaned", "datecreated", "datemodified" ]
				, hiddenGridFields = [ "content_object_type", "dependent_content_object_record_id" ]
			}
		);
	}

	private string function _dependsOnTabTitle( event, rc, prc, args={} ) {
		return translateResource( "preside-objects.tracked_content_object:viewtab.dependsOn.title" ) & ' <span class="badge">#NumberFormat( args.record.depends_on_count ?: 0 )#</span>';
	}

	private string function _dependentByTab( event, rc, prc, args={} ) {
		return objectDataTable(
			  objectName = "tracked_content_object_dependency"
			, args       = {
				  useMultiActions  = false
				, allowDataExport  = false
				, clickableRows    = true
				, gridFields       = [ "content_object_type", "content_object", "content_object_field", "soft_or_fk", "content_object_orphaned", "datecreated", "datemodified" ]
				, hiddenGridFields = [ "content_object_record_id" ]
			}
		);
	}

	private string function _dependentByTabTitle( event, rc, prc, args={} ) {
		return translateResource( "preside-objects.tracked_content_object:viewtab.dependentBy.title" ) & ' <span class="badge">#NumberFormat( args.record.dependent_by_count ?: 0 )#</span>';
	}

	private void function preFetchRecordsForGridListing( event, rc, prc, args={} ) {
		if ( !contentDependencyTrackerService.showHiddenRecords() ) {
			args.extraFilters.append( {
				  filter       = "tracked_content_object.hidden is null or tracked_content_object.hidden = :tracked_content_object.hidden"
				, filterParams = { "tracked_content_object.hidden"=false }
			} );
		}
		if ( !contentDependencyTrackerService.showAllOrphanedRecords() ) {
			args.extraFilters.append( {
				  filter       = "tracked_content_object.orphaned is null or tracked_content_object.orphaned = :tracked_content_object.orphaned"
				, filterParams = { "tracked_content_object.orphaned"=false }
			} );
		}
	}

	private void function extraTopRightButtonsForViewRecord( event, rc, prc, args={} ) {
		var contentType = prc.record.content_type ?: "";
		var contentId   = prc.record.content_id   ?: "";
		var orphaned    = isBoolean( prc.record.orphaned ?: "" ) && prc.record.orphaned;

		args.actions = args.actions ?: [];

		args.actions.append( {
			  link      = event.buildAdminLink( objectName="tracked_content_object" )
			, btnClass  = "btn-default"
			, iconClass = "fa-reply"
			, globalKey = "b"
			, title     = translateResource( "preside-objects.tracked_content_object:backToListing.btn" )
		} );

		if ( !orphaned ) {
			args.actions.append( {
				link      = _getContentObjectRecordLink( contentType, contentId, event )
				, btnClass  = "btn-info"
				, iconClass = "fa-external-link"
				, globalKey = "l"
				, title     = translateResource( "preside-objects.tracked_content_object:recordLink.btn" )
			} );
		}
	}

	private void function extraRecordActionsForGridListing( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";
		var record     = args.record     ?: {};

		var contentType = record.content_type ?: "";
		var contentId   = record.content_id   ?: "";
		var orphaned    = isBoolean( record.orphaned ?: "" ) && record.orphaned;

		if ( !orphaned && len( contentType ) && len( contentId ) ) {
			args.actions = args.actions ?: [];
			args.actions.append( {
				  link       = _getContentObjectRecordLink( contentType, contentId, event )
				, icon       = "fa-external-link"
				, contextKey = "l"
			} );
		}
	}

	private string function _getContentObjectRecordLink( required string contentType, required string contentId, any event ) {

		if ( contentDependencyTrackerService.hasCustomRecordLinkRenderer( objectName=arguments.contentType ) ) {
			return renderContent(
				  renderer = contentDependencyTrackerService.getCustomRecordLinkRenderer( objectName=arguments.contentType )
				, data     = arguments.contentId
			);
		}

		// default to use general datamanager logic / Preside core can also automatically deal with page type objects to automatically link to the site tree
		return event.buildAdminLink( objectName=arguments.contentType, recordId=arguments.contentId );
	}

	public string function linkSystemConfigRecord( event, rc, prc, args={} ) {
		var record = args.record ?: {};

		return _getContentObjectRecordLink( "system_config", record.content_id, event );
	}

	public string function linkToTracker( event, rc, prc ) {

		var contentObject = contentDependencyTrackerService.detectContentObjectByRequestContext( rc );

		if ( !isEmpty( contentObject ) ) {
			return renderView( view="/admin/datamanager/tracked_content_object/_linkToTracker", args=contentObject );
		}

		return "";
	}

	private void function extraTopRightButtonsForObject( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";

		args.actions = args.actions ?: [];

		args.actions.append( {
			  link      = event.buildAdminLink( linkto="datamanager.tracked_content_object.removeOrphansAction" )
			, btnClass  = "btn-danger"
			, iconClass = "fa-trash"
			, globalKey = "d"
			, title     = translateResource( "preside-objects.tracked_content_object:removeOrphansTask.btn" )
		} );
	}

	public void function removeOrphansAction( event, rc, prc, args={} ) {

		var taskId = createTask(
			  event             = "admin.datamanager.tracked_content_object.removeOrphansInBgThread"
			, runNow            = true
			, adminOwner        = event.getAdminUserId()
			, discardOnComplete = false
			, title             = "preside-objects.tracked_content_object:removeOrphansTask.title"
			, returnUrl         = event.buildAdminLink( objectName="tracked_content_object" )
		);

		setNextEvent( url=event.buildAdminLink( linkTo="adhoctaskmanager.progress", queryString="taskId=" & taskId ) );
	}

	private boolean function removeOrphansInBgThread( event, rc, prc, args={}, logger, progress ) {

		contentDependencyTrackerService.removeOrphanedContentObjects( logger=logger );

		return true;
	}
}