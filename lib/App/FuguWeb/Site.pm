# ex:ts=8 sw=4:
# $OpenBSD$
#
# Copyright (c) 2026 Dick Olsson <hi@senzilla.io>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use v5.36;

package App::FuguWeb::Site;

use App::FuguWeb;
use App::FuguWeb::Index;
use App::FuguWeb::Keys;
use App::FuguWeb::Page;
use App::FuguWeb::Render;
use File::Find ();
use File::Path qw(remove_tree);
use File::Spec;
use Fugu::File;
use Fugu::Log;
use Fugu::Process;
use POSIX ();

# App::FuguWeb::Site - the whole build.
#
# One method renders the site: probe the renderers, refuse an output
# directory that no build may own, lint every manual source, stage the
# mdoc sources, copy the assets, render every page, remove the staging,
# and remove what the site no longer holds. Each step reports its own
# failure and stops the build. A site that is half rendered must not
# look like a success.
#
# The build reads nothing from the network, writes nothing outside the
# output directory, and gives the same bytes for the same checkout.

# The staging directory for the mdoc sources, inside the output
# directory. mandoc decides between a local link and a link to the
# manual host by looking for a file named %N.%S in its working
# directory, so every source has to sit in one place under the name
# that a cross-reference uses.
#
# App::FuguWeb holds the name, because the description must refuse a
# key directory that would collide with it.
use constant STAGING_DIR => App::FuguWeb::STAGING_DIR;

# The stylesheet that ships with the tool, under the share path.
use constant SHARE_STYLESHEET => 'share/fuguweb/style.css';

# App::FuguWeb::Site->new(%args):
#	config => $config	the site description (required)
#	out    => $dir		the output directory (required)
#	log    => $logger	default: Fugu::Log->default
#	render => $render	default: one over the same description
sub new ( $class, %args )
{
	my $config = $args{config};
	die 'config parameter required'
	    unless defined $config;

	my $log = $args{log} // Fugu::Log->default;

	# A trailing slash would break each path that this class cuts
	# out of a walk. File::Find writes the root without one, so
	# the substr that makes a relative path would run past the
	# end and answer undef. The clean reads that answer as 'no
	# stranger', and it would then remove a tree that it never
	# looked at.
	my $out = $args{out};
	$out =~ s{(?<=.)/+\z}{} if defined $out;

	return bless {
		config => $config,
		out    => $out,
		log    => $log,
		render => $args{render} // App::FuguWeb::Render->new(
			config => $config,
			log    => $log
		),
	}, $class;
}

# $self->config:
#	The site description.
sub config ($self) { return $self->{config}; }

# $self->staging:
#	The mdoc staging directory. It lives inside the output
#	directory and never reaches the published tree.
sub staging ($self)
{
	return $self->{out} . '/' . STAGING_DIR;
}

# $self->missing_tool:
#	The renderer that failed the probe of the last build, or
#	undef. The caller maps it to its own exit code without a
#	second probe.
sub missing_tool ($self)
{
	return $self->{missing_tool};
}

# $self->build:
#	Render the whole site. The method returns true on success, and
#	undef with a message in the log otherwise. The probe comes
#	first, so the failure names the tool that is missing and never
#	blames a manual source for it.
sub build ($self)
{
	$self->{missing_tool} = $self->{render}->probe;
	if ( defined $self->{missing_tool} ) {
		$self->{log}
		    ->error( '%s is not installed', $self->{missing_tool} );
		return;
	}

	$self->_check_target    or return;
	$self->_lint            or return;
	$self->_prepare_output  or return;
	$self->_stage_mdoc      or return;
	$self->_copy_stylesheet or return;
	$self->_copy_assets     or return;
	$self->_write_keys      or return;
	$self->_render_pages    or return;
	$self->_render_manuals  or return;

	# Staging is a build detail. A published tree that carries it
	# would serve the mdoc sources beside the pages made from them.
	remove_tree( $self->staging, { safe => 0 } );

	return $self->_prune_output;
}

# $self->clean:
#	Remove the output directory. The method returns true when the
#	directory is gone, whether or not it was there to begin with.
#
#	The method removes a built site and refuses anything else. It
#	deletes a tree without asking, so the one thing it must never
#	do is delete a tree the build did not make.
sub clean ($self)
{
	$self->_check_target or return;
	return 1 unless -d $self->{out};

	my $stranger = $self->_stranger;
	if ( defined $stranger ) {
		$self->{log}->error(
'%s holds %s, which no build made; refusing to remove it',
			$self->{out}, $stranger
		);
		return;
	}

	remove_tree( $self->{out}, { safe => 0 } );

	return -e $self->{out} ? undef : 1;
}

# $self->_stranger:
#	The first entry of the output directory that no build makes,
#	or undef when every entry is one.
#
#	A build writes plain files: one flat directory of them, the
#	key directory tree below it, and the staging directory while
#	it runs. A directory that the description does not name is
#	therefore not part of a site, and so is anything below it.
#
#	The rule is stricter than the one the prune reads. A prune
#	runs after a build of this description, which establishes what
#	the output holds. A clean runs on a directory that the caller
#	named. It deletes the tree without asking, so it must refuse
#	whatever it cannot account for.
sub _stranger ($self)
{
	my $named = $self->_named;

	my @found;
	File::Find::find( {
			no_chdir => 1,
			wanted   => sub { push @found, $File::Find::name },
		},
		$self->{out} );

	for my $path ( sort @found ) {
		next if $path eq $self->{out};

		my $relative = substr $path, 1 + length $self->{out};

		# A symlink is never something that a build wrote.
		return $relative if -l $path;

		# The staging directory is a build detail, and the
		# build writes one flat directory of sources into it.
		# A tree below it is somebody else's.
		if ( App::FuguWeb::path_below( $relative, STAGING_DIR ) ) {
			next if $relative eq STAGING_DIR;
			next
			    if $relative =~ m{\A\Q@{[STAGING_DIR]}\E/[^/]+\z}
			    && $self->_build_made($relative);
			return $relative;
		}

		# A directory holds a name of the site, or it holds the
		# files of whoever made it.
		if ( -d $path ) {
			next
			    if
			    grep { App::FuguWeb::path_below( $_, $relative ) }
			    keys %$named;
			return $relative;
		}

		# A plain file of the top level is one that a build
		# writes, whatever the description names today. A
		# renamed manual leaves its old page there. A file
		# below the root belongs to the key directory, so the
		# site must name it.
		return $relative unless $self->_build_made($relative);
		next             unless $relative =~ m{/};
		return $relative unless $named->{$relative};
	}

	return;
}

# $self->_named:
#	Every path that the site holds, as a hash reference. The set
#	is empty for a description that did not load, so the clean
#	then accepts one flat directory of files and no more.
#
#	The clean deletes without asking, so it reads the inventory
#	and never a prefix. A prefix would accept any depth below the
#	key directory, and a target that holds keys/deep/mine.txt is
#	not a site.
sub _named ($self)
{
	my $config = $self->{config};
	return {} unless defined $config->path;

	return { map { $_ => 1 } $config->inventory };
}

# $self->_prefixes:
#	The directories of the output that a build writes into: the
#	staging directory, and the two of the key directory. A build
#	writes one flat directory of files, and those prefixes below
#	it.
#
#	The set holds a prefix and not each path of the inventory. A
#	key that the description drops leaves its file behind, and the
#	prune must own that file to remove it. A directory that the
#	description never named holds the files of whoever made it,
#	and neither the prune nor the clean may touch one.
sub _prefixes ($self)
{
	my @prefix = (STAGING_DIR);

	if ( defined $self->{config}->keys_dir ) {
		push @prefix, $self->{config}->keys_dir,
		    App::FuguWeb::Keys::WELL_KNOWN;
	}

	return \@prefix;
}

# $self->_owns($path, $prefixes):
#	Report whether a build writes a path of the output. A build
#	writes a name at the top level, and a name below a prefix that
#	it writes into.
sub _owns ( $self, $path, $prefixes )
{
	return 1 unless $path =~ m{/};

	return scalar grep { App::FuguWeb::path_below( $path, $_ ) } @$prefixes;
}

# $self->_check_target:
#	Refuse an output directory that must never be written into or
#	removed. The build and the clean both go through here, because
#	--out reaches them both and the setting it overrides is checked
#	in the description.
#
#	The rule is not "inside the project": the tests and the CI both
#	build into a temporary directory outside it. The rule is that
#	the target may not be the root of the filesystem, the home
#	directory, the project root, or any directory that holds the
#	project.
sub _check_target ($self)
{
	my $out = $self->{out};
	unless ( defined $out && length $out ) {
		$self->{log}->error('No output directory');
		return;
	}

	my $target = _absolute($out);
	my $root   = _absolute( $self->{config}->root );
	my $home   = defined $ENV{HOME} ? _absolute( $ENV{HOME} ) : undef;

	my $why;
	$why = 'the root of the filesystem' if $target eq '/';
	$why = 'the home directory'
	    if !$why && defined $home && $target eq $home;
	$why = 'the project root' if !$why && $target eq $root;
	$why = 'above the project'
	    if !$why && App::FuguWeb::path_below( $root, $target );

	return 1 unless $why;

	$self->{log}->error( 'The output directory %s is %s', $out, $why );

	return;
}

# $self->_prune_output:
#	Remove what the site no longer holds. A manual that was renamed
#	leaves its old page behind, and the next build would publish
#	both. The build owns the output directory, so it owns the
#	removal too.
sub _prune_output ($self)
{
	my %expected = map { $_ => 1 } $self->{config}->inventory;

	my $paths = App::FuguWeb::list_tree( $self->{out} );
	unless ($paths) {
		$self->{log}->error( 'Cannot read %s: %s', $self->{out}, $! );
		return;
	}

	my $prefixes = $self->_prefixes;

	for my $path (@$paths) {
		next if $expected{$path};

		# An empty directory is a leaf of the walk. The one
		# that the build owns goes to _prune_dirs, and a report
		# here would name a directory that the same run then
		# removes. Every other one is a stray, and it reports
		# like a stray file.
		if ( -d $self->{out} . "/$path" ) {
			next
			    if $self->_owns( $path, $prefixes )
			    && $path =~ m{/};
			next
			    if grep { App::FuguWeb::path_below( $path, $_ ) }
			    @$prefixes;

			$self->{log}->warning(
				'%s is in the output, and the site does not'
				    . ' name it',
				$path
			);
			next;
		}

		# A plain file that a build writes, and nothing else. A
		# file below a directory that the description does not
		# name belongs to whoever made it, and the checks
		# report it.
		unless (   $self->_owns( $path, $prefixes )
			&& $self->_build_made($path) )
		{
			$self->{log}->warning(
				'%s is in the output, and the site does not'
				    . ' name it',
				$path
			);
			next;
		}

		$self->{log}
		    ->info( 'Removing %s, which the site no longer holds',
			$path );
		unlink "$self->{out}/$path"
		    or
		    $self->{log}->warning( 'Cannot remove %s: %s', $path, $! );
	}

	return $self->_prune_dirs;
}

# $self->_prune_dirs:
#	Remove every empty directory of the output. A key directory
#	that the description dropped leaves its own directory behind.
#	The next check would then report a tree that no site holds.
#
#	rmdir refuses a directory that still holds a name, so the walk
#	needs no second test: a directory that the site still uses
#	stays. The deepest path comes last from the walk, so the
#	reverse order removes a tree from the leaves up.
sub _prune_dirs ($self)
{
	my $prefixes = $self->_prefixes;

	my @dirs;
	File::Find::find( {
			no_chdir => 1,
			wanted   => sub {
				push @dirs, $File::Find::name
				    if -d $File::Find::name
				    && !-l $File::Find::name;
			},
		},
		$self->{out} );

	# A prefix that the build writes into, and a directory below
	# one. The output directory itself stays. A site with no page
	# is a build that failed, and a removed output directory would
	# hide that from every check. A directory that no build made
	# stays as well, empty or not.
	for my $dir ( reverse sort @dirs ) {
		next if $dir eq $self->{out};

		my $relative = substr $dir, 1 + length $self->{out};
		next
		    unless grep { App::FuguWeb::path_below( $relative, $_ ) }
		    @$prefixes;

		rmdir $dir;
	}

	return 1;
}

# $self->_build_made($name):
#	Report whether one entry of the output directory is something
#	a build makes: a plain file, and never a symlink. The clean
#	and the prune share this rule, so the two can never disagree
#	about what a build owns.
sub _build_made ( $self, $name )
{
	my $path = "$self->{out}/$name";

	return -f $path && !-l $path ? 1 : 0;
}

# _absolute($path):
#	The path with no trailing slash and no parent step, resolved
#	against the working directory when it is relative.
#
#	The function collapses '..' itself. File::Spec->canonpath
#	leaves it alone by design, and a guard that compared the
#	uncollapsed form would let '<project>/..' through as a
#	directory it had never seen.
#
#	The path need not exist, so no symlink is resolved. A symlink
#	is not a way around the guard: the build refuses to write
#	through one, and the clean removes the link and not its target.
sub _absolute ($path)
{
	my $absolute = File::Spec->canonpath( File::Spec->rel2abs($path) );

	my @parts;
	for my $part ( split m{/}, $absolute ) {
		next if $part eq '' || $part eq '.';
		if ( $part eq '..' ) {
			pop @parts;
			next;
		}
		push @parts, $part;
	}

	return @parts ? '/' . join '/', @parts : '/';
}

# $self->pod_date:
#	The date that every POD page carries: the date of the last
#	commit, and today when git does not answer. git does not
#	preserve file times, so a build that read one would give
#	different bytes on every checkout.
sub pod_date ($self)
{
	my $result = Fugu::Process->run(
		cmd => [
			'git', '-C', $self->{config}->root,
			'log', '-1', '--format=%cs'
		],
	);
	my $date = $result->{success} ? $result->{stdout} : '';
	$date =~ s/\s+//g;

	return length $date ? $date : POSIX::strftime( '%Y-%m-%d', localtime );
}

# $self->_mdoc_manuals:
#	Every mdoc source of the site, in group order.
sub _mdoc_manuals ($self)
{
	return grep { !$_->is_pod }
	    map { $_->manuals } $self->{config}->groups;
}

# $self->_lint:
#	Refuse a malformed manual source before anything is rendered.
sub _lint ($self)
{
	my @paths = map { $_->path } $self->_mdoc_manuals;

	return $self->{render}->lint(@paths);
}

# $self->_prepare_output:
#	Create the output directory and the staging directory inside
#	it. The output directory is created on purpose. The recipe that
#	this replaced got it as a side effect of the staging mkdir,
#	which would have broken the moment the staging step moved.
sub _prepare_output ($self)
{
	Fugu::File->ensure_dir( $self->{out} ) or return;
	$self->_check_links                    or return;

	# A staging directory left by an interrupted build would leak
	# stale sources into this one.
	remove_tree( $self->staging, { safe => 0 } ) if -d $self->staging;

	return Fugu::File->ensure_dir( $self->staging );
}

# $self->_check_links:
#	Refuse a symlink anywhere in the output directory.
#
#	A build writes a file by name, and an open follows a link. A
#	link in the output would therefore send the bytes of the site
#	to whatever it points at. That is outside the output
#	directory, and outside the project. The key directory makes it
#	worse: a link at .well-known would take the published key
#	material with it.
#
#	The test comes before the first write, because a link that the
#	prune finds at the end has already served.
sub _check_links ($self)
{
	my $paths = App::FuguWeb::list_tree( $self->{out} );
	unless ($paths) {
		$self->{log}->error( 'Cannot read %s: %s', $self->{out}, $! );
		return;
	}

	# A link that the build never writes through is somebody
	# else's, and a build leaves it. The build writes the
	# inventory and no more. A link on one of those paths, or on a
	# directory of one, is the whole rule.
	my %named = map { $_ => 1 } $self->{config}->inventory;
	my %above;
	for my $named ( keys %named ) {
		my @parts = split m{/}, $named;
		pop @parts;

		my $prefix = '';
		for my $part (@parts) {
			$prefix = length $prefix ? "$prefix/$part" : $part;
			$above{$prefix} = 1;
		}
	}

	for my $path (@$paths) {
		next unless -l $self->{out} . "/$path";
		next unless $named{$path} || $above{$path};

		$self->{log}->error(
			'%s holds the symlink %s; a build writes no file'
			    . ' through a link',
			$self->{out}, $path
		);
		return;
	}

	return 1;
}

# $self->_copy($from, $to):
#	Copy one file, as bytes, through Fugu::File. The method
#	returns true on success, and undef with a message in the log
#	otherwise.
sub _copy ( $self, $from, $to )
{
	my $bytes = Fugu::File->read($from);
	unless ( defined $bytes ) {
		$self->{log}->error( 'Cannot read %s', $from );
		return;
	}

	return Fugu::File->write( $to, $bytes );
}

# $self->_stage_mdoc:
#	Copy every mdoc source into the staging directory, under the
#	name that a cross-reference refers to it by.
sub _stage_mdoc ($self)
{
	for my $manual ( $self->_mdoc_manuals ) {
		$self->_copy( $manual->path,
			$self->staging . '/' . $manual->staged_name )
		    or return;
	}

	return 1;
}

# $self->_copy_stylesheet:
#	Copy the base stylesheet into the output. The sheet ships with
#	the tool, and the stylesheet setting overrides the search. The
#	search finds the file in a checkout through this module's
#	location, and under the share tree of an installed App-FuguWeb
#	distribution.
sub _copy_stylesheet ($self)
{
	my $named = $self->{config}->stylesheet;
	my $path =
	    defined $named
	    ? $self->{config}->root
	    . "/$named"
	    : Fugu::File->share_path(
		SHARE_STYLESHEET,
		from => __FILE__,
		dist => 'App-FuguWeb'
	    );

	unless ( defined $path && -f $path ) {

		# A site with no stylesheet must not look like a
		# success, so the message names the path that failed.
		$self->{log}->error(
			'Cannot find the stylesheet: %s',
			$named // SHARE_STYLESHEET
		);
		return;
	}

	return $self->_copy( $path,
		$self->{out} . '/' . App::FuguWeb::STYLESHEET );
}

# $self->_copy_assets:
#	Copy every asset of the source directory. The description
#	decides which files those are, so the build and the checks read
#	the same list.
sub _copy_assets ($self)
{
	my $dir = $self->{config}->source_path;

	for my $name ( $self->{config}->assets ) {
		$self->_copy( "$dir/$name", $self->{out} . "/$name" )
		    or return;
	}

	return 1;
}

# $self->_write_keys:
#	Write the key directory. The build copies each key file and
#	the manifest pair as they stand. It generates the KEYS file,
#	the human page, the Web Key Directory tree and security.txt
#	through the Fugu modules.
#
#	A description with no keys block writes no key directory, so
#	every site that predates it keeps its output.
#
#	The site build cannot sign, so the manifest pair is a source
#	file. A build that signed would prove that the builder holds
#	the key, and never that the release does.
sub _write_keys ($self)
{
	my $config = $self->{config};
	return 1 unless defined $config->keys_dir;

	my $keys = App::FuguWeb::Keys->new( config => $config );

	# The generation comes first, because it runs the guards of
	# Fugu::KeyDir over every armored key. A copy that ran first
	# would leave a private key block in the output of a build
	# that then failed.
	my $generated = $keys->generated;
	unless ($generated) {
		$self->{log}->error( 'The key directory is not usable: %s',
			$keys->error );
		return;
	}

	for my $copy ( $keys->copies ) {
		$self->_write_out(
			$copy->{to},
			sub {
				my $bytes = Fugu::File->read( $copy->{from} );
				$self->{log}
				    ->error( 'Cannot read %s', $copy->{from} )
				    unless defined $bytes;
				return $bytes;
			} ) or return;
	}

	for my $path ( sort keys %$generated ) {
		$self->_write_out( $path, sub { return $generated->{$path} } )
		    or return;
	}

	return 1;
}

# $self->_write_out($path, $bytes):
#	Write one file of the key directory, at a path below the
#	output directory. Fugu::File->write opens the file and creates
#	no parent, and the Web Key Directory sits three directories
#	down, so the parent comes first.
#
#	The bytes arrive through a code reference, so a read that
#	fails reports its own path and this method reports none.
sub _write_out ( $self, $path, $bytes )
{
	my $target = $self->{out} . "/$path";

	my $dir = $target =~ s{/[^/]+\z}{}r;
	Fugu::File->ensure_dir($dir) or return;

	my $data = $bytes->() // return;

	return Fugu::File->write( $target, $data );
}

# $self->_render_pages:
#	Render every page block. A body fragment is already HTML, a
#	Markdown file goes through lowdown, and the index comes from
#	App::FuguWeb::Index.
sub _render_pages ($self)
{
	my $config = $self->{config};
	my $page   = App::FuguWeb::Page->new( config => $config );
	my $index  = App::FuguWeb::Index->new( config => $config );

	for my $entry ( $config->pages ) {
		my $fragment;

		if ( $entry->{source} eq 'body' ) {
			my $path = $config->source_path( $entry->{value} );
			$fragment = Fugu::File->read($path);
			unless ( defined $fragment ) {
				$self->{log}->error( 'Cannot read %s', $path );
				return;
			}
		}
		elsif ( $entry->{source} eq 'markdown' ) {
			$fragment =
			    $self->{render}
			    ->markdown( $config->root . '/' . $entry->{value} );
			return unless defined $fragment;
		}
		else {
			$fragment = $index->body;
		}

		$page->write( $self->{out} . '/' . $entry->{file},
			$entry->{title}, $fragment )
		    or return;
	}

	return 1;
}

# $self->_render_manuals:
#	Render one page for each manual of each group.
sub _render_manuals ($self)
{
	my $config = $self->{config};
	my $page   = App::FuguWeb::Page->new( config => $config );
	my $date   = $self->pod_date;

	for my $group ( $config->groups ) {
		for my $manual ( $group->manuals ) {
			my $fragment =
			      $manual->is_pod
			    ? $self->{render}
			    ->pod( $manual->path, $manual->name, $date )
			    : $self->{render}
			    ->mdoc( $manual->staged_name, $self->staging );
			return unless defined $fragment;

			$page->write(
				$self->{out} . '/' . $manual->page,
				$manual->name . '(' . $manual->section . ')',
				$fragment
			) or return;
		}
	}

	return 1;
}

1;
