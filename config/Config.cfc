component {

	public void function configure( required struct config ) {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		settings.features.globalLinkToDependencyTracker = { enabled=false, siteTemplates=[ "*" ], widgets=[] };

		settings.adminConfigurationMenuItems.append( "dependencyTracker" );

		settings.adminMenuItems.dependencyTracker = {
			  buildLinkArgs = { objectName="tracked_content_object" }
			, activeChecks  = { datamanagerObject="tracked_content_object" }
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
				  "admin.datamanager.viewRecord"                      = { contentTypeParam="object"   , contentIdParam="id"       }
				, "admin.datamanager.editRecord"                      = { contentTypeParam="object"   , contentIdParam="id"       }
				, "admin.assetmanager.editAsset"                      = { contentType="asset"         , contentIdParam="asset"    }
				, "admin.sites.editSite"                              = { contentType="site"          , contentIdParam="id"       }
				, "admin.sitetree.editPage"                           = { contentType="page"          , contentIdParam="id"       }
				, "admin.emailcenter.systemTemplates.template"        = { contentType="email_template", contentIdParam="template" }
				, "admin.emailcenter.systemTemplates.edit"            = { contentType="email_template", contentIdParam="template" }
				, "admin.emailcenter.systemTemplates.configurelayout" = { contentType="email_template", contentIdParam="template" }
				, "admin.emailcenter.systemTemplates.stats"           = { contentType="email_template", contentIdParam="template" }
				, "admin.emailcenter.systemTemplates.logs"            = { contentType="email_template", contentIdParam="template" }
				, "admin.emailCenter.customTemplates.preview"         = { contentType="email_template", contentIdParam="id"       }
				, "admin.emailcenter.customTemplates.edit"            = { contentType="email_template", contentIdParam="id"       }
				, "admin.emailcenter.customTemplates.settings"        = { contentType="email_template", contentIdParam="id"       }
				, "admin.emailcenter.customTemplates.configureLayout" = { contentType="email_template", contentIdParam="id"       }
				, "admin.emailcenter.customTemplates.stats"           = { contentType="email_template", contentIdParam="id"       }
				, "admin.emailcenter.customTemplates.logs"            = { contentType="email_template", contentIdParam="id"       }
			}
		};

		settings.enum.dependencyTrackerContentTypes = StructKeyArray( settings.contentDependencyTracker.trackObjects );
	}
}