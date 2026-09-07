#!/usr/bin/env perl
# ex:ts=8 sw=4:
# App::FuguWeb::Keys: the description blocks, the published tree, and
# every rule of the check.
#
# The test builds each key directory in a File::Temp directory. It
# never reads the repository, and it runs no command: the key material
# is a fixture, so the test needs neither signify(1) nor gpg(1).

use v5.36;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use Digest::SHA ();
use File::Path qw(make_path);
use File::Temp qw(tempdir);

use_ok('App::FuguWeb::Check');
use_ok('App::FuguWeb::Config');
use_ok('App::FuguWeb::Keys');
use_ok('App::FuguWeb::Render');
use_ok('App::FuguWeb::Site');
use_ok('Fugu::Log');

# A real signify public key, and a real OpenPGP public key. Both are
# fixtures of this file: signify(1) verified the manifest below
# against the first, and gpg(1) imported the second.
my $SIGNIFY = <<'KEY';
untrusted comment: fugubsd-1-release public key
RWRPa1Nd3YmPwqMMjxtMv+TPkCbHp43jYR8s7TGqxx1EI70I2bKmsAlE
KEY

my $OPENPGP = <<'KEY';
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEap8KyxYJKwYBBAHaRw8BAQdA/6e7KzznAvEb2GEzYP1hlO69/FHDWy/cXJot
91Zpg+q0FHNlY3VyaXR5QGZ1Z3Vic2Qub3JniJMEExYKADsWIQSYOF9+PI20LwzG
2+jrLQSjr07OVQUCap8KywIbAwULCQgHAgIiAgYVCgkICwIEFgIDAQIeBwIXgAAK
CRDrLQSjr07OVYrkAP4nNPl6GHRSz1HlUlOc2ojAwvr8XDIifmAU1cc5W8xyogD+
LtLBaFuVI8Oc1PPnYVpof5lHHSJd9KR/4F/S7omdUAU=
=+npU
-----END PGP PUBLIC KEY BLOCK-----
KEY

# The v4 fingerprint of the key above, and the Web Key Directory hash
# of the local part 'security'. Both were computed outside this file:
# gpg(1) printed the fingerprint, and an independent z-base-32 encoder
# gave the hash.
use constant {
	FINGERPRINT => '98385F7E3C8DB42F0CC6DBE8EB2D04A3AF4ECE55',
	WKD_HASH    => 't5s8ztdbon8yzntexy6oz5y48etqsnbb',
};

# The signature of the manifest is opaque to the site build, which
# copies it and never reads it. The fixture is therefore any bytes.
my $SIGNATURE = "untrusted comment: signature\nAAAA\n";

my $KEYS_BLOCK = <<'RC';
keys "keys" {
	org     = fugubsd
	contact = mailto:security@fugubsd.org
	expires = 2027-09-07T00:00:00Z
	url     = https://www.fugubsd.org/keys
}

key "fugubsd-1-release" {
	status = current
	since  = 2026-09-07
}

key "fugubsd-1-contact" {
	status      = current
	since       = 2026-09-07
	email       = security@fugubsd.org
	fingerprint = 98385F7E3C8DB42F0CC6DBE8EB2D04A3AF4ECE55
}
RC

# digest($bytes):
#	The lowercase hex SHA256 of the bytes, as the manifest writes
#	it.
sub digest ($bytes)
{
	return lc Digest::SHA::sha256_hex($bytes);
}

# manifest(%file):
#	The text of a SHA256 manifest over the named bytes, in the
#	sorted order that Fugu::Signify writes.
sub manifest (%file)
{
	my $text = '';
	$text .= "SHA256 ($_) = " . digest( $file{$_} ) . "\n"
	    for sort keys %file;

	return $text;
}

# spew($path, $bytes):
#	Write one file, and every directory above it.
sub spew ( $path, $bytes )
{
	my $dir = $path =~ s{/[^/]+\z}{}r;
	make_path($dir) unless -d $dir;

	open my $fh, '>', $path or die "Cannot write $path: $!";
	binmode $fh;
	print {$fh} $bytes;
	close $fh;

	return $path;
}

# project(%args):
#	A whole small project with a key directory, and its root.
#
#	%args:
#		rc    => $text    the description, default the block above
#		keys  => \%file   the key directory, default both keys
#		files => \%file   more files, as path => bytes
sub project (%args)
{
	my $root = tempdir( CLEANUP => 1 );

	my %keys = %{
		$args{keys} // {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
		}
	};

	# The manifest names every key file, so a fixture that adds a
	# key never has to restate the digests.
	spew( "$root/web/keys/$_", $keys{$_} ) for keys %keys;
	unless ( exists $args{files} && exists $args{files}{'web/keys/SHA256'} )
	{
		spew( "$root/web/keys/SHA256", manifest(%keys) );
	}
	spew( "$root/web/keys/SHA256.sig", $SIGNATURE );

	spew( "$root/web/index.body.html", "<h1>Home</h1>\n" );

	my $rc = $args{rc} // $KEYS_BLOCK;
	spew( "$root/.fuguwebrc", <<"RC" );
site       = Example
source_dir = web
out_dir    = out

nav "index.html" {
	label = Home
}

page "index.html" {
	title = Home
	body  = index.body.html
}

$rc
RC

	spew( "$root/$_", $args{files}{$_} ) for keys %{ $args{files} // {} };

	return $root;
}

# load($root):
#	Load the description of the project, and return it with the
#	reason of a failure.
sub load ($root)
{
	my $reason;
	my $config =
	    App::FuguWeb::Config->load( root => $root, error => \$reason );

	return ( $config, $reason );
}

# problems($root):
#	The key problems of the project, as one string.
sub problems ($root)
{
	my ( $config, $reason ) = load($root);
	return "the description does not load: $reason" unless $config;

	return join "\n",
	    App::FuguWeb::Keys->new( config => $config )->problems;
}

subtest 'the published paths' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'a description with a key directory loads' )
	    or diag $reason;

	is( $config->keys_dir,     'keys',    'keys_dir' );
	is( $config->keys_org,     'fugubsd', 'keys_org' );
	is( $config->keys_contact, 'mailto:security@fugubsd.org',
		'keys_contact' );
	is( $config->keys_expires, '2027-09-07T00:00:00Z', 'keys_expires' );
	is( $config->keys_url, 'https://www.fugubsd.org/keys', 'keys_url' );

	my %path = map { $_ => 1 } $config->key_paths;
	for my $name (
		'keys/fugubsd-1-release.pub', 'keys/fugubsd-1-contact.asc',
		'keys/SHA256',                'keys/SHA256.sig',
		'keys/KEYS',                  'keys/index.html',
		'.well-known/openpgpkey/hu/' . WKD_HASH,
		'.well-known/openpgpkey/policy',
		'.well-known/security.txt'
	    )
	{
		ok( $path{$name}, "the inventory names $name" );
	}

	is( scalar keys %path, 9, 'and it names nothing else' );

	my %inventory = map { $_ => 1 } $config->inventory;
	ok( $inventory{'keys/KEYS'}, 'the inventory of the site holds them' );
	ok( $inventory{'index.html'}, 'beside the pages of the description' );
};

subtest 'the key blocks' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my ($signify) =
	    grep { $_->{type} eq 'signify' } $config->site_keys;
	is( $signify->{name}, 'fugubsd-1-release.pub', 'the file name' );
	is( $signify->{stem}, 'fugubsd-1-release',     'the stem' );
	is( $signify->{serial},  1,         'the serial' );
	is( $signify->{purpose}, 'release', 'the purpose' );
	is( $signify->{status},  'current', 'the status' );
	is( $signify->{email},   undef,     'a signify key has no email' );

	my ($openpgp) =
	    grep { $_->{type} eq 'openpgp' } $config->site_keys;
	is( $openpgp->{name}, 'fugubsd-1-contact.asc',
		'the type comes from the extension' );
	is( $openpgp->{email}, 'security@fugubsd.org', 'the email' );
	is( $openpgp->{wkd}, WKD_HASH, 'the Web Key Directory hash' );
	is( $openpgp->{fingerprint}, FINGERPRINT, 'the fingerprint' );
};

subtest 'the generated files' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $keys      = App::FuguWeb::Keys->new( config => $config );
	my $generated = $keys->generated;
	ok( $generated, 'the key directory generates' ) or diag $keys->error;

	my $apache = $generated->{'keys/KEYS'};
	like( $apache, qr/^fugubsd-1-contact$/m, 'KEYS names the stem' );
	like( $apache, qr/^fingerprint: \Q@{[FINGERPRINT]}\E$/m,
		'KEYS names the fingerprint' );
	like( $apache, qr/-----BEGIN PGP PUBLIC KEY BLOCK-----/,
		'KEYS holds the armored body' );
	unlike( $apache, qr/fugubsd-1-release/,
		'and it holds no signify key, which gpg cannot read' );

	my $page = $generated->{'keys/index.html'};
	like( $page, qr{<title>Keys },     'the index page has a title' );
	like( $page, qr{href="\.\./style\.css"},
		'and it steps back to the stylesheet of the root' );
	like( $page, qr{href="\.\./index\.html"},
		'and back to the entry page' );
	like( $page, qr{href="fugubsd-1-release\.pub"},
		'and it links each key beside it' );
	like( $page, qr{<td>release</td>}, 'and it names each purpose' );

	my $binary = $generated->{ '.well-known/openpgpkey/hu/' . WKD_HASH };
	ok( defined $binary, 'the Web Key Directory file exists' );
	unlike( $binary, qr/-----BEGIN/,
		'and it holds the binary form, which the direct method serves'
	);
	is( ord( substr $binary, 0, 1 ), 0x98,
		'whose first byte opens a public key packet' );

	like( $generated->{'.well-known/openpgpkey/policy'}, qr/^#/,
		'the policy file carries a comment and no flag' );

	my $security = $generated->{'.well-known/security.txt'};
	like( $security, qr{^Contact: mailto:security\@fugubsd\.org$}m,
		'security.txt holds the contact' );
	like( $security, qr{^Expires: 2027-09-07T00:00:00Z$}m,
		'and the expiry' );
	like(
		$security,
		qr{^Encryption: \Qhttps://www.fugubsd.org/keys/fugubsd-1-contact.asc\E$}m,
		'and an Encryption field that points at the current key'
	);
};

subtest 'a signify key alone generates no OpenPGP file' => sub {
	my $root = project(
		keys => { 'fugubsd-1-release.pub' => $SIGNIFY },
		rc   => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}
RC
	);

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my %path = map { $_ => 1 } $config->key_paths;
	ok( !$path{'keys/KEYS'}, 'no KEYS file, which would be empty' );
	ok( !$path{'.well-known/openpgpkey/policy'}, 'no policy file' );
	ok( !$path{'.well-known/security.txt'},
		'and no security.txt without a contact' );
	ok( $path{'keys/index.html'}, 'the human page stays' );

	my $keys      = App::FuguWeb::Keys->new( config => $config );
	my $generated = $keys->generated;
	ok( $generated, 'the key directory generates' ) or diag $keys->error;
	is_deeply( [ sort keys %$generated ],
		['keys/index.html'], 'and it writes the page only' );
};

subtest 'a description with no keys block' => sub {
	my $root = tempdir( CLEANUP => 1 );
	spew( "$root/web/index.body.html", "<h1>Home</h1>\n" );
	spew( "$root/.fuguwebrc", <<'RC' );
site = Example

page "index.html" {
	title = Home
	body  = index.body.html
}
RC

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	is( $config->keys_dir, undef, 'it names no key directory' );
	is( scalar $config->site_keys, 0, 'and it holds no key' );
	is( scalar $config->key_paths, 0, 'so the inventory gains nothing' );

	my %inventory = map { $_ => 1 } $config->inventory;
	ok( $inventory{'index.html'}, 'and the site is unchanged' );

	is( scalar App::FuguWeb::Check->new( config => $config, out => 'out' )
		->_check_keys,
		0, 'the checks find nothing to say' );
};

subtest 'a good directory has no problem' => sub {
	is( problems( project() ), '', 'nothing to report' );
};

subtest 'a key file that no block names' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'fugubsd-2-release.pub' => $SIGNIFY,
		}
	);

	like( problems($root), qr{^keys/fugubsd-2-release\.pub: no key block},
		'the check names the file' );
};

subtest 'a name that the pattern does not match' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'notes.txt'             => "a note\n",
		}
	);

	like( problems($root), qr{^keys/notes\.txt: unknown key extension},
		'the check names the extension' );
};

subtest 'two current keys of one purpose' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-2-release.pub' => $SIGNIFY,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-2-release" {
	status = current
}
RC
	);

	like(
		problems($root),
		qr{the purpose release holds 2 current keys},
		'the check names the purpose and the count'
	);
};

subtest 'a digest that no longer matches' => sub {
	my $root = project(
		files => {
			'web/keys/SHA256' => manifest(
				'fugubsd-1-release.pub' => "other bytes\n",
				'fugubsd-1-contact.asc' => $OPENPGP,
			)
		}
	);

	like(
		problems($root),
		qr{^keys/fugubsd-1-release\.pub: the manifest records \w+, and the file digests to},
		'the check names both digests'
	);
};

subtest 'a manifest that does not name a key' => sub {
	my $root = project(
		files => {
			'web/keys/SHA256' =>
			    manifest( 'fugubsd-1-contact.asc' => $OPENPGP )
		}
	);

	like( problems($root),
		qr{^keys/SHA256: it does not name fugubsd-1-release\.pub}m,
		'the check names the key' );
};

subtest 'a manifest that names a key of no block' => sub {
	my $root = project(
		files => {
			'web/keys/SHA256' => manifest(
				'fugubsd-1-release.pub' => $SIGNIFY,
				'fugubsd-1-contact.asc' => $OPENPGP,
				'fugubsd-9-release.pub' => $SIGNIFY,
			)
		}
	);

	like(
		problems($root),
		qr{^keys/SHA256: it names fugubsd-9-release\.pub, which is not a key}m,
		'the check names the line'
	);
};

subtest 'a fingerprint that the key does not give' => sub {
	my $root = project( rc => <<'RC' );
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status      = current
	fingerprint = 0000000000000000000000000000000000000000
}
RC

	like(
		problems($root),
		qr{^keys/fugubsd-1-contact\.asc: the description declares 0{40}, and the key gives \Q@{[FINGERPRINT]}\E$}m,
		'the check names both fingerprints'
	);
};

subtest 'a description that the loader refuses' => sub {
	my %case = (
		'an unknown setting of a key block' => [
			qr{key "fugubsd-1-release" names the unknown setting sinse},
			<<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
	sinse  = 2026-09-07
}
RC
		],
		'a status outside the vocabulary' => [
			qr{holds the status active, and the vocabulary is current, next, retired},
			<<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = active
}
RC
		],
		'a block that names no file' => [
			qr{key "fugubsd-9-release" names no file in web/keys},
			<<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-9-release" {
	status = current
}
RC
		],
		'an email on a signify key' => [
			qr{key "fugubsd-1-release" names email, and fugubsd-1-release\.pub is a signify key},
			<<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
	email  = x@example.org
}
RC
		],
		'an org word that no key name can hold' => [
			qr{keys "keys": org must hold lower-case letters},
			<<'RC'
keys "keys" {
	org = Fugu BSD
}

key "fugubsd-1-release" {
	status = current
}
RC
		],
		'a contact with no expiry' => [
			qr{names a contact and no expires},
			<<'RC'
keys "keys" {
	org     = fugubsd
	contact = mailto:security@fugubsd.org
}

key "fugubsd-1-release" {
	status = current
}
RC
		],
		'an expiry with no contact' => [
			qr{names expires and no contact},
			<<'RC'
keys "keys" {
	org     = fugubsd
	expires = 2027-09-07T00:00:00Z
}

key "fugubsd-1-release" {
	status = current
}
RC
		],
		'a url that is not absolute' => [
			qr{url is www\.fugubsd\.org/keys, which is not an absolute URL},
			<<'RC'
keys "keys" {
	org = fugubsd
	url = www.fugubsd.org/keys
}

key "fugubsd-1-release" {
	status = current
}
RC
		],
		'a keys block with no key block' => [
			qr{keys "keys" holds no key block},
			<<'RC'
keys "keys" {
	org = fugubsd
}
RC
		],
		'a duplicate key block' => [
			qr{key "fugubsd-1-release" is declared twice},
			<<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-release" {
	status = retired
}
RC
		],
	);

	for my $name ( sort keys %case ) {
		my ( $pattern, $rc ) = @{ $case{$name} };
		my $root = project(
			keys => { 'fugubsd-1-release.pub' => $SIGNIFY },
			rc   => $rc
		);

		my ( $config, $reason ) = load($root);
		ok( !$config, "$name is refused" );
		like( $reason, $pattern, "and the reason names it" );
	}
};

subtest 'two key files under one stem' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-release.asc' => $OPENPGP,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}
RC
	);

	my ( $config, $reason ) = load($root);
	ok( !$config, 'the description is refused' );
	like(
		$reason,
		qr{names fugubsd-1-release\.asc and fugubsd-1-release\.pub, and one key block names one file},
		'because one purpose holds one current key of one type'
	);
};

subtest 'a directory with no manifest' => sub {
	for my $missing (qw(SHA256 SHA256.sig)) {
		my $root = project();
		unlink "$root/web/keys/$missing";

		my ( $config, $reason ) = load($root);
		ok( !$config, "a directory with no $missing is refused" );
		like( $reason, qr{keys "keys" holds no \Q$missing\E in web/keys},
			'and the reason names the file' );
	}
};

# site($config, $out):
#	A site over the description, with a quiet log and a renderer
#	that runs nothing.
#
#	The fixtures hold no manual and no Markdown, so no renderer is
#	ever called. The probe still tests all three, so it gets three
#	programs that exist. The key directory needs no renderer, and
#	a test of it must not skip where mandoc is absent.
sub site ( $config, $out )
{
	return App::FuguWeb::Site->new(
		config => $config,
		out    => $out,
		log    => Fugu::Log->new( mode => Fugu::Log::MODE_QUIET() ),
		render => App::FuguWeb::Render->new(
			config  => $config,
			mandoc  => '/bin/true',
			lowdown => '/bin/true',
		),
	);
}

# tree($dir):
#	Every file below the directory, as sorted relative paths.
sub tree ($dir)
{
	return sort @{ App::FuguWeb::list_tree($dir) // [] };
}

subtest 'the build writes the whole tree' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	my @expected = sort ( $config->inventory );
	is_deeply( [ tree($out) ],
		\@expected, 'the output holds the inventory and nothing else' );

	ok( -s "$out/keys/KEYS", 'the KEYS file is not empty' );
	ok( -s "$out/.well-known/openpgpkey/hu/" . WKD_HASH,
		'the Web Key Directory file is not empty' );

	# A copied file goes in byte for byte. The manifest is signed,
	# so one changed byte breaks the signature of the whole
	# directory.
	open my $fh, '<', "$out/keys/fugubsd-1-release.pub"
	    or die "Cannot read the published key: $!";
	my $published = do { local $/; <$fh> };
	close $fh;
	is( $published, $SIGNIFY, 'a key file is copied byte for byte' );

	is( scalar App::FuguWeb::Check->new( config => $config, out => $out )
		->run,
		0, 'and the built site passes its checks' );

	# A build must give the same bytes for the same checkout, or a
	# published diff shows a change that nobody made.
	my %first = map { $_ => -s "$out/$_" } tree($out);
	ok( site( $config, $out )->build, 'a second build succeeds' );
	my %second = map { $_ => -s "$out/$_" } tree($out);
	is_deeply( \%second, \%first, 'and writes the same tree' );
};

subtest 'the build prunes a key that the description dropped' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );
	ok( -e "$out/keys/fugubsd-1-contact.asc", 'the OpenPGP key is there' );
	ok( -d "$out/.well-known/openpgpkey/hu", 'and its directory' );

	# The description drops the OpenPGP key, and the key directory
	# then holds a signify key alone.
	spew( "$root/.fuguwebrc", <<'RC' );
site       = Example
source_dir = web
out_dir    = out

nav "index.html" {
	label = Home
}

page "index.html" {
	title = Home
	body  = index.body.html
}

keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}
RC
	unlink "$root/web/keys/fugubsd-1-contact.asc";
	spew( "$root/web/keys/SHA256",
		manifest( 'fugubsd-1-release.pub' => $SIGNIFY ) );

	my ( $dropped, $why ) = load($root);
	ok( $dropped, 'the smaller description loads' ) or diag $why;
	ok( site( $dropped, $out )->build, 'the build succeeds again' );

	ok( !-e "$out/keys/fugubsd-1-contact.asc",
		'the key that the site no longer holds is gone' );
	ok( !-e "$out/keys/KEYS", 'and the KEYS file with it' );
	ok( !-e "$out/.well-known",
		'and the well-known tree, which is now empty' );
	ok( -e "$out/keys/fugubsd-1-release.pub", 'the signify key stays' );
	ok( -d $out, 'and the output directory itself stays' );

	is( scalar App::FuguWeb::Check->new( config => $dropped, out => $out )
		->run,
		0, 'the site passes its checks' );
};

subtest 'the checks read the whole output tree' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	# A walk of one level would take every published key for a
	# stray file, and a stray file below the root for nothing.
	spew( "$out/keys/stray.txt", "left behind\n" );

	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;
	is_deeply( [@problems],
		['keys/stray.txt: in the output but not in the site'],
		'a stray file below the root is reported by its path' );
};

subtest 'clean removes the whole tree' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );
	ok( -d "$out/keys", 'the key directory is there' );

	ok( site( $config, $out )->clean, 'the clean succeeds' );
	ok( !-e $out, 'and the whole tree is gone' );
};

subtest 'clean refuses a tree that no build made' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	# A symlink below the root. The clean deletes a tree without
	# asking, so it must refuse anything that a build cannot have
	# written.
	symlink '/etc/passwd', "$out/keys/link"
	    or plan skip_all => 'cannot make a symlink here';

	ok( !site( $config, $out )->clean, 'the clean refuses' );
	ok( -e "$out/keys/fugubsd-1-release.pub", 'and removes nothing' );
};

subtest 'clean refuses a directory that the site does not name' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	# An empty directory holds no file, so a walk that reads files
	# alone would not see it and the clean would take the tree.
	mkdir "$out/archive" or die "Cannot make the directory: $!";

	ok( !site( $config, $out )->clean, 'the clean refuses' );
	ok( -e "$out/keys/fugubsd-1-release.pub", 'and removes nothing' );

	rmdir "$out/archive" or die "Cannot remove the directory: $!";
	ok( site( $config, $out )->clean, 'and it succeeds once it is gone' );
};

done_testing();
