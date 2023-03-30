component extends="app.extensions.preside-ext-better-view-record-screen.base.BetterDatamanagerBase" {

	property name="trackerService" inject="ContentDependencyTrackerService";
	property name="configService"  inject="ContentDependencyTrackerConfigurationService";

	variables.infoCol1 = [ "object_name", "hidden", "orphaned" ];
	variables.infoCol2 = [ "record_id", "last_scanned", "requires_scanning" ];

	variables.tabs = [ "dependsOn", "dependentBy" ];

	private void function rootBreadcrumb( event, rc, prc, arg={} ) {
		// leaving this method empty removes the "Data Manager" within the bread crumb trail
		// resulting in "Home > Tracked Content Objects" as the root breadcrumb
	}

	private string function objectBreadcrumb() {
		event.addAdminBreadCrumb(
			  title = "Dependency Tracker"
			, link  = event.buildAdminLink( objectName="tracked_content_record" )
		);
	}

	private string function recordBreadcrumb() {
		var recordLabel = prc.recordLabel    ?: "";
		var recordId    = prc.recordId       ?: "";
		var record      = prc.record         ?: {};
		var objectName  = record.object_name ?: "";

		event.addAdminBreadCrumb( 
			  title = renderContent( "objectName", objectName, [ "adminDatatable", "admin" ] ) & ": " & htmlEditFormat( recordLabel )
			, link  = event.buildAdminLink( objectName="tracked_content_record", recordId=recordId )
		);
	}

	private string function _infoCardObject_name( event, rc, prc, args={} ) {
		var record = args.record ?: {};

		return '<strong>#translateResource( "preside-objects.tracked_content_record:field.object_name.title" )#</strong>:&nbsp; #renderContent( "objectName", record.object_name, [ "adminDatatable", "admin" ] )#';
	}

	private string function _infoCardRecord_id( event, rc, prc, args={} ) {
		var record = args.record ?: {};

		return '<strong>#translateResource( "preside-objects.tracked_content_record:field.record_id.title" )#</strong>:&nbsp; #record.record_id#';
	}

	private string function _infoCardLast_scanned( event, rc, prc, args={} ) {
		var record = args.record ?: {};

		return '<strong>#translateResource( "preside-objects.tracked_content_record:field.last_scanned.title" )#</strong>:&nbsp; #dateTimeFormat( record.last_scanned, "yyyy-mm-dd HH:mm:ss" )#';
	}

	private string function _infoCardOrphaned( event, rc, prc, args={} ) {
		var record = args.record ?: {};
		var orphaned = isBoolean( record.orphaned ?: "" ) && record.orphaned;

		return orphaned ? '<span class="badge badge-important">#translateResource( "preside-objects.tracked_content_record:field.orphaned.title" )#</span>' : '';
	}

	private string function _infoCardHidden( event, rc, prc, args={} ) {
		var record = args.record ?: {};
		var hidden = isBoolean( record.hidden ?: "" ) && record.hidden;

		return hidden ? '<span class="badge">#translateResource( "preside-objects.tracked_content_record:field.hidden.title" )#</span>' : '';
	}

	private string function _infoCardRequires_scanning( event, rc, prc, args={} ) {
		var record = args.record ?: {};
		var requiresScanning = isBoolean( record.requires_scanning ?: "" ) && record.requires_scanning;

		return requiresScanning ? '<span class="badge badge-warning">#translateResource( "preside-objects.tracked_content_record:field.requires_scanning.title" )#</span>' : '';
	}

	private string function _dependsOnTab( event, rc, prc, args={} ) {
		return objectDataTable(
			  objectName = "tracked_content_record_dependency"
			, args       = {
				  useMultiActions  = false
				, allowDataExport  = false
				, clickableRows    = true
				, gridFields       = [
					  "dependent_content_record_object_name"
					, "dependent_content_record"
					, "content_record_field"
					, "soft_or_fk"
					, "dependent_content_record_orphaned"
					, "datecreated"
					, "datemodified"
				]
				, hiddenGridFields = [
					  "content_record_object_name"
					, "dependent_content_record_id"
				]
			}
		);
	}

	private string function _dependsOnTabTitle( event, rc, prc, args={} ) {
		return translateResource( "preside-objects.tracked_content_record:viewtab.dependsOn.title" ) & ' <span class="badge">#NumberFormat( args.record.depends_on_count ?: 0 )#</span>';
	}

	private string function _dependentByTab( event, rc, prc, args={} ) {
		return objectDataTable(
			  objectName = "tracked_content_record_dependency"
			, args       = {
				  useMultiActions  = false
				, allowDataExport  = false
				, clickableRows    = true
				, gridFields       = [
					  "content_record_object_name"
					, "content_record"
					, "content_record_field"
					, "soft_or_fk"
					, "content_record_orphaned"
					, "datecreated"
					, "datemodified"
				]
				, hiddenGridFields = [
					"content_record_id"
				]
			}
		);
	}

	private string function _dependentByTabTitle( event, rc, prc, args={} ) {
		return translateResource( "preside-objects.tracked_content_record:viewtab.dependentBy.title" ) & ' <span class="badge">#NumberFormat( args.record.dependent_by_count ?: 0 )#</span>';
	}

	private void function preFetchRecordsForGridListing( event, rc, prc, args={} ) {
		if ( !configService.showHiddenRecords() ) {
			args.extraFilters.append( {
				  filter       = "tracked_content_record.hidden is null or tracked_content_record.hidden = :tracked_content_record.hidden"
				, filterParams = { "tracked_content_record.hidden"=false }
			} );
		}
		if ( !configService.showAllOrphanedRecords() ) {
			args.extraFilters.append( {
				  filter       = "tracked_content_record.orphaned is null or tracked_content_record.orphaned = :tracked_content_record.orphaned"
				, filterParams = { "tracked_content_record.orphaned"=false }
			} );
		}
	}

	private void function extraTopRightButtonsForViewRecord( event, rc, prc, args={} ) {
		var objectName = prc.record.object_name ?: "";
		var recordId   = prc.record.record_id   ?: "";
		var orphaned   = isBoolean( prc.record.orphaned ?: "" ) && prc.record.orphaned;

		args.actions = args.actions ?: [];

		args.actions.append( {
			  link      = event.buildAdminLink( objectName="tracked_content_record" )
			, btnClass  = "btn-default"
			, iconClass = "fa-reply"
			, globalKey = "b"
			, title     = translateResource( "preside-objects.tracked_content_record:backToListing.btn" )
		} );

		if ( !orphaned ) {
			args.actions.append( {
				  link      = _getContentRecordLink( objectName, recordId, event )
				, btnClass  = "btn-info"
				, iconClass = "fa-external-link"
				, globalKey = "l"
				, title     = translateResource( "preside-objects.tracked_content_record:recordLink.btn" )
			} );
		}
	}

	private void function extraRecordActionsForGridListing( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";
		var record     = args.record     ?: {};

		var objectName = record.object_name ?: "";
		var recordId   = record.record_id   ?: "";
		var orphaned   = isBoolean( record.orphaned ?: "" ) && record.orphaned;

		if ( !orphaned && len( objectName ) && len( recordId ) ) {
			args.actions = args.actions ?: [];
			args.actions.append( {
				  link       = _getContentRecordLink( objectName, recordId, event )
				, icon       = "fa-external-link"
				, contextKey = "l"
			} );
		}
	}

	private string function _getContentRecordLink( required string objectName, required string recordId, any event ) {

		if ( configService.hasCustomRecordLinkRenderer( objectName=arguments.objectName ) ) {
			return renderContent(
				  renderer = configService.getCustomRecordLinkRenderer( objectName=arguments.objectName )
				, data     = arguments.recordId
			);
		}

		// default to use general datamanager logic / Preside core can also automatically deal with page type objects to automatically link to the site tree
		return event.buildAdminLink( objectName=arguments.objectName, recordId=arguments.recordId );
	}

	private void function extraTopRightButtonsForObject( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";

		args.actions = args.actions ?: [];

		args.actions.append( {
			  link      = event.buildAdminLink( linkto="datamanager.tracked_content_record.removeOrphansAction" )
			, btnClass  = "btn-danger"
			, iconClass = "fa-trash"
			, globalKey = "d"
			, title     = translateResource( "preside-objects.tracked_content_record:removeOrphansTask.btn" )
		} );
	}

	public void function removeOrphansAction( event, rc, prc, args={} ) {

		var taskId = createTask(
			  event             = "admin.datamanager.tracked_content_record.removeOrphansInBgThread"
			, runNow            = true
			, adminOwner        = event.getAdminUserId()
			, discardOnComplete = false
			, title             = "preside-objects.tracked_content_record:removeOrphansTask.title"
			, returnUrl         = event.buildAdminLink( objectName="tracked_content_record" )
		);

		setNextEvent( url=event.buildAdminLink( linkTo="adhoctaskmanager.progress", queryString="taskId=" & taskId ) );
	}

	private boolean function removeOrphansInBgThread( event, rc, prc, args={}, logger, progress ) {

		trackerService.removeOrphanedContentRecords( logger=logger );

		return true;
	}
}