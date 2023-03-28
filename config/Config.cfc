component {

	public void function configure( required struct config ) {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		settings.features.globalLinkToDependencyTracker = { enabled=false, siteTemplates=[ "*" ], widgets=[] };

		settings.adminConfigurationMenuItems.append( "dependencyTracker" );

		settings.adminMenuItems.dependencyTracker = {
			  buildLinkArgs = { objectName="tracked_content_record" }
			, activeChecks  = { datamanagerObject="tracked_content_record" }
			, icon          = "fa-exchange"
			, title         = "cms:dependencyTracker.navigation.link"
		};

		conf.interceptors.prepend( { class="app.extensions.preside-ext-content-dependency-tracker.interceptors.ContentDependencyTrackerInterceptor", properties={} } );

		settings.contentDependencyTracker = {
			  autoEnableDbTextFields = false
			, trackObjects = {
				  asset                  = { enabled=true }
				, site                   = { enabled=true }
				, rules_engine_condition = { enabled=true }
				, page = {
					  enabled    = true
					, properties = {
						  main_content = { enabled=true  }
						, parent_page  = { enabled=false }
						, site         = { enabled=false }
					}
				}
				, system_config = {
					  enabled                = true
					, hideIrrelevantRecords  = true
					, labelGenerator         = "dependencyTrackerSystemConfigLabelGenerator"
					, labelRenderer          = "dependencyTrackerSystemConfigLabelRenderer"
					, viewRecordLinkRenderer = "dependencyTrackerSystemConfigLinkRenderer"
					, properties             = {
						  value = { enabled=true }
						, site  = { enabled=false }
					}
				}
				, accessDenied       = { enabled=true }
				, forgotten_password = { enabled=true }
				, homepage           = { enabled=true }
				, login              = { enabled=true }
				, notFound           = { enabled=true }
				, reset_password     = { enabled=true }
				, standard_page      = { enabled=true }
			}
			, linkToTrackerEvents = {
				  "admin.datamanager.viewRecord"                      = { objectNameParam="object"   , recordIdParam="id"       }
				, "admin.datamanager.editRecord"                      = { objectNameParam="object"   , recordIdParam="id"       }
				, "admin.assetmanager.editAsset"                      = { objectName="asset"         , recordIdParam="asset"    }
				, "admin.sites.editSite"                              = { objectName="site"          , recordIdParam="id"       }
				, "admin.sitetree.editPage"                           = { objectName="page"          , recordIdParam="id"       }
				, "admin.emailcenter.systemTemplates.template"        = { objectName="email_template", recordIdParam="template" }
				, "admin.emailcenter.systemTemplates.edit"            = { objectName="email_template", recordIdParam="template" }
				, "admin.emailcenter.systemTemplates.configurelayout" = { objectName="email_template", recordIdParam="template" }
				, "admin.emailcenter.systemTemplates.stats"           = { objectName="email_template", recordIdParam="template" }
				, "admin.emailcenter.systemTemplates.logs"            = { objectName="email_template", recordIdParam="template" }
				, "admin.emailCenter.customTemplates.preview"         = { objectName="email_template", recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.edit"            = { objectName="email_template", recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.settings"        = { objectName="email_template", recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.configureLayout" = { objectName="email_template", recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.stats"           = { objectName="email_template", recordIdParam="id"       }
				, "admin.emailcenter.customTemplates.logs"            = { objectName="email_template", recordIdParam="id"       }
			}
		};

		settings.enum.dependencyTrackerObjectNames = StructKeyArray( settings.contentDependencyTracker.trackObjects );
	}
}