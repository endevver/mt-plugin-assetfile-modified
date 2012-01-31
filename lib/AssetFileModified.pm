package AssetFileModified;

use strict;
use warnings;
use Carp qw( croak );
use Data::Dumper;

#use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect );
our $logger;


=head1 NAME

AssetFileModified - Display assets sorted by actual upload time

=head1 DESCRIPTION

Blah blah blah....

=cut

=head1 METHODS

=head2 hdlr_asset_file_modified($ctx, $args)

This method is the handler for the mt:AssetFileModified template tag which
returns the modification timestamp (mtime) of the file represented by the
asset in context.

=head3 Attributes

See mt:Date for all supported attributes and attribute values: L<http://movabletype.org/tags/mtdate>

=head3 Example

The following:

    <mt:Assets><mt:AssetLabel> was uploaded <mt:AssetFileModified relative="1">
    </mt:Assets>

Could be used to output something like this:

    IMG_1195.JPG was uploaded 1 hour ago
    IMG_1194.JPG was uploaded 3 days ago
    n599367413_1714467_7256.jpg was uploaded 3 months ago
    ohhai.jpg was uploaded Dec 23 2009


=cut

sub hdlr_asset_file_modified {
    my ($ctx, $args) = @_;
    my $asset = $ctx->stash('asset')
        or return $ctx->_no_asset_error();
    return unless $args->{ts} = $asset->file_modified;
    return $ctx->_hdlr_date( $args );
}

=head2 hdlr_assets_uploaded($ctx, $args)

This method is the handler for the C<mt:AssetsUploaded> block tag which is
provided simply as a shorter way of writing:

    <mt:Assets sort_by="file_mtime" sort_order="descend">
        [...]
    </mt:Assets>

=head3 Attributes

After applying the sort paramters and loading the assets, this method hands
them off to the L<mt:Assets> handler method to do the rest of the work.
Because of that, C<mt:AssetsUploaded> supports all of the same attributes and
attribute values as C<mt:Assets> and produces the exact same results.

NOTE: Using a C<sort_by> value with C<mt:AssetsUploaded> will not override
C<file_mtime> but instead be applied as a secondary sort:

    <mt:AssetsUploaded sort_by="somefield">

becomes

    <mt:Assets sort_by="file_mtime,somefield">

=cut

sub hdlr_assets_uploaded {
    my $ctx             = shift;
    my ( $args, $cond ) = @_;
    my $class           = MT->model('asset');

    # Set defaults
    $args->{limit}  ||= delete $args->{lastn} || 50;
    $args->{offset} ||= 0;
    $args->{sort_by} = 'file_mtime'; # To preserve sort in _hdlr_assets

    local $ctx->{__stash}{assets};

    my (%blog_terms, %blog_args, %terms, %args);
    $ctx->set_blog_load_context($args, \%blog_terms, \%blog_args)
        or return;

    # Default load terms apply blog filter (if any) but NO class filter
    %terms = ( %blog_terms, class => '*' );

    # If 'type' arg is specified, override class filter.
    # Delete the arg so it's not reapplied later in _hdlr_assets
    if ( my $type = delete $args->{type} ) {
        $terms{class} = [ split( ',',  $type ) ];
    }

    # Load arguments, apply blog args, limit and offset.
    # Turn default created_on sort into a 2-column sort with
    # file_mtime applied first.
    my $sort_order = ($args->{sort_order}||'') eq 'ascend' ? 'ASC' : 'DESC';
    %args  = (
        %blog_args,
        sort      => $args->{sort_by},
        direction => $args->{sort_order} || 'descend',
        limit     => $args->{limit},
        offset    => $args->{offset},
    );

    # Adds parent filter (skips any generated files such as thumbnails)
    my $is_null         = 'is null';
    $args{null}{parent} = 1;
    $terms{parent}      = \$is_null;

    my @assets = $class->load( \%terms, \%args )
        or return $ctx->_hdlr_pass_tokens_else( @_ );

    $ctx->{__stash}{assets} = \@assets;
    return $ctx->_hdlr_assets( $args, $cond );
}

=head2 on_upload( $cb, %params )

This method is the handler for the cms_upload_file.file callback which is
triggered whenever a file is uploaded via the CMS. It ensures that all newly
uploaded files (including replacements of existing files) have a file_modified
property.

=cut

sub on_upload {
    my ( $cb, %params ) = @_;
    $params{asset}->file_modified(undef);
}

=head2 cb_list_assets_param( $cb, $app, $param, $tmpl )

This method is a template param callback handler for the list_assets mode. It
is triggered anytime a user navigates to an asset listing screen at which
point it ensures that all assets on the current page of the listing have a
C<file_modified> property stored in their asset metadata record.

This is mostly just backup for the upgrade script. Probably isn't necessary
anymore....

=cut

sub cb_list_assets_param {
    my ( $cb, $app, $param, $tmpl ) = @_;

    # Iterate through assets in listing, load the asset and then call
    # $asset->file_modified which will force a value to be calculated if one
    # does not exist
    foreach my $obj ( @{$param->{object_loop}} ) {
        next unless my $id = $obj->{id};
        my $type  = 'asset.'.$obj->{asset_type};
        my $asset = MT->model('asset')->load( $id )
            or next;

        my $ts_meta_db = $asset->file_modified() || '';
        ## Debugging ##
        # warn Dumper({ 
        #     path          => $obj->{file_path},
        #     file_modified => $ts_meta_db || '',
        #     modified_on   => $obj->{modified_on}
        # });
    }
}

=head2 cb_edit_asset_param( $cb, $app, $param, $tmpl )

This method is a template param callback handler for the edit_asset mode.
It is triggered anytime a user navigates to an asset's editing screen at
which point it flushes the C<file_modified> property of the asset and causes
it to be read again from the file system.

This provides a way to force-refresh an asset's file_modified property which
may be needed if the asset is replaced or modified directly on the filesystem.
Since this plugin only updates the C<file_modified> property upon upload
through the CMS (for performance reasons), such manipulations would not be
automatically recognized by the system.

=cut

sub cb_edit_asset_param {
    my ( $cb, $app, $param, $tmpl ) = @_;
    # warn 'Asset file_modified: '.
    $param->{asset}->file_modified(undef);
}

=head2 upgrade_set_file_modified( $upgrader_app )

This method is the upgrade handler for the plugin which is responsible for
populating the file_modified property for all asset records.

=cut

sub upgrade_set_file_modified {
    my $upgrader = shift;
    my $iter = MT->model('asset')->load_iter({ class => '*' });
    $upgrader->progress(
        MT::Upgrade->translate_escape(
            "Populating assets with file_modified property...")
    );

    while ( my $asset = $iter->() ) {
        printf STDERR "Updating asset %s with path %s (%s)\n",
            $asset->id, $asset->file_path,
            (-e $asset->file_path ? "OK" : "NOPE");

        $asset->file_modified(undef)
            if $asset->file_path and -e $asset->file_path;
    }
    0;
}


#====================================================================
package MT::Asset;
#====================================================================

use Carp qw( croak );
use MT::Util qw( epoch2ts );
no warnings 'redefine';

=head2 file_modified( $asset )

=cut

sub file_modified {
    my $asset         = shift;

    # Check if the file exists first.
    return if !$asset->file_path || !-e $asset->file_path;

    my $file_modified = $asset->file_mtime(@_) || 0;
    return $file_modified if $file_modified;

    # Derive modified timestamp from stat() of file path
    my $ts = eval { (stat( $asset->file_path ))[9] };
    unless ( $ts ) {
        warn sprintf( 'Error getting modified timestamp for '
                     .'asset ID %d (path: %s): %s',
                     $asset->id,
                     ($asset->file_path||''),
                     ($@||'')
        );
        return;
    }

    # Format it in YYYYMMDDHHMMSS format in asset blog's timezone (if any)
    $ts = epoch2ts( $asset->blog, $ts );

    if ( $ts != $file_modified ) {
        my $mt = MT->instance;
        # $mt->run_callbacks(
        #     'asset.file_modified_update', $mt, $asset, $ts
        # );
        $asset->file_mtime( $file_modified = $ts );
        $asset->save;
    }

    return $file_modified;
}


sub init_app {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    ##l4p $logger->debug('init_app:', l4mtdump([@_]));
    MT->model('asset')->add_trigger( pre_search => \&asset_pre_search );
}

sub asset_pre_search {
    my $cb = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    ###l4p $logger->debug('pre_search:', l4mtdump([@_]));
}

sub cb_asset_preload {
    my $cb = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    ###l4p $logger->debug('preload:', l4mtdump([@_]));
}

sub cb_asset_postload {
    my $cb = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    ###l4p $logger->debug('postload:', l4mtdump([@_]));
}


1;

=head1 LIMITATIONS

This plugin does not currently have the capability to automatically detect
direct modification of asset files on the filesystem.

=cut

__END__

