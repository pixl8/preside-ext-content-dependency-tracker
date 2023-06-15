# Preside Content Dependency Tracker

This is an extension for [Preside](https://www.preside.org) that provides tracking of content records and their dependencies. Content records could be pages, assets, links, rules engine conditions, system settings, helper records. etc. The extension comes with a set of already configured content records for tracking from the Preside Core. It's up to you to configure it in a way that fits your site or application.

As of now this extension is considered **alpha** and therefore to be used with caution. It has not been tested extensively with large databases yet.

In detail the extension provides the following functionality:

* admin interface to track configured content records including their dependencies (bi-directional)
* automatic tracking tasks (full scanning/indexing and also index on changes)
* deal with both hard references (database foreign keys) and also soft references (e.g. records used in rich editor content)
* Possibility to identifiy orphans and broken dependencies
* link in and out from/to Preside System (e.g. from an asset in asset manager see number of dependencies and directly link into the tracker)

ATTENTION: as of now this extension depends on the better-view-record-screen extension which is not open sourced (yet), stay tuned, as it will be soon...

## Installation

From the root of your application, type the following command in a terminal:

```
box install preside-ext-content-dependency-tracker
```

## Configuration

All settings for this extension are located in the `Config.cfc` as in the following way:

```
settings.contentDependencyTracker = {
	  autoEnableDbTextFields  = false
	, autoTrackRelatedObjects = false
	, trackObjects = {
		  asset  = { enabled=true }
		...
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
	}
	, linkToTrackerEvents = {
		  "admin.datamanager.viewRecord"               = { objectNameParam="object"   , recordIdParam="id"       }
		, "admin.datamanager.editRecord"               = { objectNameParam="object"   , recordIdParam="id"       }
		, "admin.assetmanager.editAsset"               = { objectName="asset"         , recordIdParam="asset"    }
		, "admin.sites.editSite"                       = { objectName="site"          , recordIdParam="id"       }
		, "admin.sitetree.editPage"                    = { objectName="page"          , recordIdParam="id"       }
		, "admin.emailcenter.systemTemplates.template" = { objectName="email_template", recordIdParam="template" }
		...
	}
};
```

`autoEnableDbTextFields` will automatically enable all `dbtype="text"` fields on all objects that are enabled for tracking.

`autoTrackRelatedObjects` will automatically track also related content objects of other objects that are marked as trackable. For example you might explicitly mark links and assets as trackable but nothing else. Then when enabling auto-tracking, the system will automatically also determine any object that links to assets or links. Only content objects that are explictely excluded from tracking (enabled=false) will then not be tracked. Content object that are not explicitly marked to be tracked will be hidden by default from the Dependency Tracker listing, but will show up as dependencies in trackable objects.

`trackObjects.{any_preside_object}.enabled` will enable (or disable) an object for tracking.

Enabling/disabling properties is done like this: `trackObjects.{preside_object_name}.properties.{property_name}.enabled`

Foreign Key properties (`many-to-one` and `many-to-many` relationships) will be automatically enabled if this is configured in the System Settings (see below).
If you explicitly want to disable a specific FK from being indexed, then disable it here in the `Config.cfc`.
For example the default configuration disables the parent_page and site properties, see above.

Non-relationsship fields always need to be manually enabled, e.g. have a look at the `value` property from the `system_config` object in the default configuration above.

`hideIrrelevantRecords=true` will mark indexed content records as `hidden`, if no single dependency exists.
You can control to not show hidden records via System settings (see further down below).

`labelGenerator` can be used on object-level in order to have a custom content renderer to be used when generating the label of the content record.

`labelRenderer` is defined on object-level to have a custom content renderer be used to render the label of the content record.

For example the extension uses these two in combination to generate and render labels for the `system_config` object. In that case the generator uses `{category}:{setting}` for sys-config objects and the renderer uses i18n translations for those to make it render pretty (and language-aware),
e.g. you could then have a `system_config` content record with the label `website_users:default_post_login_page` which automatically renders to `Website user config: Default post login page`.

`viewRecordLinkRenderer` is used to define a custom content renderer to use for generating the link from the Dependency Tracker UI to the actual preside object record view.
By default and if nothing custom is specified the system will just use a general datamanager view record link. This might not work for some special records, e.g. in the default implementation `system_config` as well as `email_template` records need special links. See actual code of this extension how this is solved.

In order to be able to link from individual object records into the dependency tracker (and see the dependencies), the system need to know which events should be supported.

This is done by the configuration beneath `linkToTrackerEvents`.

It is a struct which has the actual Coldbox event names as the key, e.g. `admin.datamanager.viewRecord` is the standard datamanager view record event.
The configuration for each event needs to have a `recordIdParam` - this is the Request Context (`rc`) param where the logic should detect the ID of the record.
To determine the content type of the record (e.g. whether it's an asset, a page, an email_template, etc.) can be done in 2 ways. Either it's specified in a fix way using the `objectName` param, or use `objectNameParam` to have the system check for the object type in the defined `rc` param.

All these settings can be tweaked/overwritten within your site's own `Config.cfc`.

For example if you want a custom object to be added, you would do something like this:

```
settings.contentDependencyTracker = settings.contentDependencyTracker ?: {};
settings.contentDependencyTracker.trackObjects = settings.contentDependencyTracker.trackObjects ?: {};
settings.contentDependencyTracker.trackObjects.my_custom_object = { enabled=true, properties={ some_field={ enabled=true } } }
```

Note: In order to track dependencies between content records you need to make sure that both sides of the dependency are enabled for tracking.

### Annotations
All settings underneath `settings.contentDependencyTracker.trackObjects` can also be configured directly on your Preside objects via annotations. The annotations are labelled exactly the same, with the exception that a `dependencyTracker` prefix is needed.
For example the following is the `email_template.cfc` from the extension:

```
/**
 * @dependencyTrackerEnabled                true
 * @dependencyTrackerViewRecordLinkRenderer dependencyTrackerEmailTemplateLinkRenderer
 */
component {
	property name="html_body" dependencyTrackerEnabled=true;
}
```
This will enable dependency tracking for the `email_template` object and specifically check the `html_body` property for soft references to other defined content records.

### Configuring your own objects for tracking
You can configure content objects for tracking in 2 ways, either by adding them in the settings of your application's `Config.cfc` or via Preside object annotations. Annotations take precedence over `Config.cfc`. It's totally up to you which method you want to use.

If you want to track content objects from other extensions within your application, the `Config.cfc` settings are a bit handier than annotations as you do not need to create a copy of all the Preside Objects from those extensions within your application. In addition, if there are objects defined to be tracked in the settings in `Config.cfc` and these do not exist at all in the current application, they are simply ignored without an error.

## Usage

After configuration, the actual usage of the extension can be divided in 2 parts:
* automatic finding and indexing of tasks
* making use of the indexed data

### Tasks

Two scheduled tasks exist to scan and index your records for dependencies. Go to `System > Task Manager` and check the `Content` tab there.
You will find:
* `[1] Scan all content record dependencies`
* `[2] Scan changed content records for dependencies`

The first one will perform a full re-index of all records. Depending on the amount of records to be scanned, that might take a while. You could either only manually execute this or run it infrequently, e.g. nightly.
The second one should be run frequently, e.g. by default it is configured to run every 5 minutes. This only scans records that require scanning. This only works if single record indexing is enabled. See below.

### System Settings
There are a couple of switches you can turn on/off in the system settings, which you find in the Preside admin here: `System > Settings > Content Dependency Tracker`.

* `Enabled`: global switch to enable/disable the whole content tracking
* `Foreign Key Scanning`: whether FK scanning should take place or not
* `Soft Reference Scanning`: whether non-relationship fields should be scanned
* `Hide all irrelevant records`: Flag all records without dependencies as hidden (you can also have this disabled here but enable it on a per-object basis using annotations)
* `Show hidden records`: whether content records flagged as `hidden` should be shown in the Dependency Tracker listing or not.
* `Show all orphaned records`: On deletion content records are flagged as `orphaned`. This setting controls if those should be displayed in the Dependency Tracker listing or not.
* `Single Record Scanning`: Will enable content records to be flagged as `requires_scanning` on insert/update/delete.

If both FK + Soft Ref Scanning is disabled, the whole system is basically disabled.

Recommended settings to make the most out of the extension: Disable `Hide all irrelevant records` and `Show hidden records`, enable all others.

### Dependency Tracker Listing
Find the listing of Content records and there dependencies in the Preside Admin underneath `System > Dependency Tracker`.

Recommendations: Make yourself 1-click fav filters for the following two cases:
* `orphaned` > filter for `orphaned=true`
* `broken dependencies` > filter for `has more than 0 Uses matching optional filter broken`, where `broken` is a sub filter which is defined as `Dependent Content Record matches the following Dependency Tracker filter: orphaned`

### Clean-Up Orphans

There is a button in the Dependency Tracker Listing at the top right corner to remove all orphans which do not have any dependencies. You can manually execute it from time to time to get rid of obsolete data. Orphans which have dependencies will not be removed. E.g. you might have a rules engine filter used within a conditional content widget within a page - and that rules engine filter got deleted but is still in use in that page. Then the content record for this record will not be deleted.

### Link into Tracker UI from Core System

There is a feature that allows a global link to be rendered for configured content objects from anywhere in the Preside Admin into the Content Tracker. It is disabled by default but you can enable it in your `Config.cfc` as follows:

```
settings.features.globalLinkToDependencyTracker.enabled = true;
```

This will render a link whenever possible in the global navigation of the Preside Admin when viewing a record that is tracked. The link will show the number of dependencies and direct you to the content tracker. So for example if enabled you can see in the asset manager for an individual asset whether it's used and if so how often. Details of the dependencies can then be seen when clicking the link and being directed to the content record within the Dependency Tracker UI.

## Versioning

We use [SemVer](https://semver.org) for versioning. For the versions available, see the [tags on this repository](https://github.com/pixl8/preside-ext-content-dependency-tracker/releases). Project releases can also be found and installed from [Forgebox](https://forgebox.io/view/preside-ext-content-dependency-tracker).

## License

This project is licensed under the GPLv2 License - see the [LICENSE.txt](https://github.com/pixl8/preside-ext-content-dependency-tracker/blob/stable/LICENSE.txt) file for details.

## Changes / Contributions

Find all changes in the [CHANGELOG.md](https://github.com/pixl8/preside-ext-content-dependency-tracker/blob/stable/CHANGELOG.md)
Feel free to fork and pull request to contribute. Any additional feedback is very welcome - preferable via Github issues or on the Preside Slack channel.