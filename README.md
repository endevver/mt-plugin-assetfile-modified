# AssetFileModified plugin for Melody/Movable Type #

Display assets sorted by actual upload time!

## Features ##

The current version of the plugin does the following:

* Perform an upgrade procedure which creates a `file_mtime` column in the
  `mt_asset` table and populates each asset record with the modification time
  of the file it represents. (**n.b.:** If you have a lot of assets, you may
  want to use the command line script `MT_HOME/tools/upgrade`).

* The `file_mtime` column is indexed which means template designers can use
  it to sort `mt:Assets`: `<mt:Assets sort_by="file_mtime">`

* Each time an asset is uploaded (both new assets and overwrites) this plugin
  sets the `file_mtime` value accordingly in the asset record.

* Provides a template tag, **mt:AssetsUploaded**, which is exactly like
  mt:Assets except more predictable, well-behaved and has fewer characters to
  type.

* Provides a standard MT date template tag, **mt:AssetFileModified**, which
  outputs the file modification time in your desired format for the asset in
  context.

* When a user navigates to an asset listing screen, the plugin ensures that
  all assets on the current page of the listing also have a populated value
  for `file_mtime`.

* When a user navigates to any asset editing screen, the plugin flushes the
  `file_mtime` value and re-reads it from the filesystem. This provides a way
  to force-refresh an asset's `file_mtime` property which may be needed if the
  asset is replaced or modified directly on the filesystem.

## PLUGIN REQUIREMENTS ##

   * Any version of [Melody][] or [Movable Type v4.3x][MT]

[MT]:                   http://movabletype.org/
[Melody]:               http://openmelody.org/

## INSTALLATION ##

Unzip the download archive. Move the resulting folder to `$MT_HOME/plugins/`
(where `$MT_HOME` is your MT or Melody application directory).

If you use Git, you can do the following:

    cd $MT_HOME/plugins
    git clone git://github.com/endevver/mt-plugin-assetfile-modified.git

## METHODS ##

### `hdlr_asset_file_modified($ctx, $args)` ###

This method is the handler for the mt:AssetFileModified template tag which
returns the modification timestamp (mtime) of the file represented by the
asset in context.

#### Attributes ####

* Same as [mt:Date](http://movabletype.org/tags/mtdate)

### Example ###

The following:

    <mt:Assets><mt:AssetLabel> was uploaded <mt:AssetFileModified relative="1">
    </mt:Assets>

Could be used to output something like this:

    IMG_1195.JPG was uploaded 1 hour ago
    IMG_1194.JPG was uploaded 3 days ago
    n599367413_1714467_7256.jpg was uploaded 3 months ago
    ohhai.jpg was uploaded Dec 23 2009


### `hdlr_assets_uploaded($ctx, $args)` ###

This method is the handler for the `mt:AssetsUploaded` block tag which is
provided simply as a shorter way of writing:

    <mt:Assets sort_by="file_mtime" sort_order="descend">
        [...]
    </mt:Assets>

#### Attributes ####

After applying the sort paramters and loading the assets, this method hands
them off to the **mt:Assets** handler method to do the rest of the work.
Because of that, `mt:AssetsUploaded` supports all of the same attributes and
attribute values as `mt:Assets` and produces the exact same results.

NOTE: Using a `sort_by` value with `mt:AssetsUploaded` will not override
`file_mtime` but instead be applied as a secondary sort:

    <mt:AssetsUploaded sort_by="somefield">

becomes

    <mt:Assets sort_by="file_mtime,somefield">


### `on_upload( $cb, %params )` ###

This method is the handler for the cms_upload_file.file callback which is
triggered whenever a file is uploaded via the CMS. It ensures that all newly
uploaded files (including replacements of existing files) have a file_modified
property.


### `cb_list_assets_param( $cb, $app, $param, $tmpl )` ###

This method is a template param callback handler for the list_assets mode. It
is triggered anytime a user navigates to an asset listing screen at which
point it ensures that all assets on the current page of the listing have a
C<file_modified> property stored in their asset metadata record.

This is mostly just backup for the upgrade script. Probably isn't necessary
anymore....


### `cb_edit_asset_param( $cb, $app, $param, $tmpl )` ###

This method is a template param callback handler for the edit_asset mode.
It is triggered anytime a user navigates to an asset's editing screen at
which point it flushes the C<file_modified> property of the asset and causes
it to be read again from the file system.

This provides a way to force-refresh an asset's file_modified property which
may be needed if the asset is replaced or modified directly on the filesystem.
Since this plugin only updates the C<file_modified> property upon upload
through the CMS (for performance reasons), such manipulations would not be
automatically recognized by the system.


### `upgrade_set_file_modified( $upgrader_app )` ###

This method is the upgrade handler for the plugin which is responsible for
populating the file_modified property for all asset records.

### `$asset->file_modified` ###

This method provides the `file_mtime` value for the asset in question or does
the work of deriving it and saving it back into the asset record when
necessary. Passing `undef` as the only argument will flush and refresh the
value cached in the database:

    my $new_mtime = $asset->file_modified(undef);   # Already saved!

## LIMITATIONS ##

This plugin does not currently have the capability to automatically detect
direct modification of asset files on the filesystem.

## LICENSE ##

This plugin is licensed under the same terms as Perl itself.

## HELP, BUGS AND FEATURE REQUESTS ##

If you are having problems installing or using the plugin, please check out our general knowledge base and help ticket system at [help.endevver.com](http://help.endevver.com).

## COPYRIGHT ##

Copyright 2011, Endevver, LLC. All rights reserved.

## ABOUT ENDEVVER ##

We design and develop web sites, products and services with a focus on 
simplicity, sound design, ease of use and community. We specialize in 
Movable Type and offer numerous services and packages to help customers 
make the most of this powerful publishing platform.

<http://www.endevver.com/>
