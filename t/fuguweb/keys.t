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
use File::Path qw(make_path remove_tree);
use Cwd ();
use File::Temp qw(tempdir);

use_ok('App::FuguWeb::Check');
use_ok('App::FuguWeb::Config');
use_ok('App::FuguWeb::Keys');
use_ok('App::FuguWeb::Render');
use_ok('Fugu::OpenPGP');
use_ok('App::FuguWeb::CLI');
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

# A second OpenPGP public key, so a test can give one address two
# keys. gpg(1) exported it, and its own address is another one. The
# Web Key Directory hash comes from the description block, and never
# from the user ID of the key.
my $OPENPGP_TWO = <<'KEY';
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEap8SyBYJKwYBBAHaRw8BAQdAGB4kM583QvVjstiJzxMyAue0PzoV0JBkAr97
o/R0iua0EW90aGVyQGV4YW1wbGUubmV0iJMEExYKADsWIQTK2oMEZ8k4Mqd9r9sc
td/IKBFyxgUCap8SyAIbAwULCQgHAgIiAgYVCgkICwIEFgIDAQIeBwIXgAAKCRAc
td/IKBFyxrYlAP9T9c5ckirPex8DHwD1x/t/Twkkpz4aRlGffqwVg87eXgD+MUAt
sJE5p9nZI/NPUXLbEpLZ9EQotNcVXyqku3JhTQE=
=joU/
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

# slurp($path):
#	The whole file, as bytes.
sub slurp ($path)
{
	open my $fh, '<', $path or die "Cannot read $path: $!";
	binmode $fh;
	my $bytes = do { local $/; <$fh> };
	close $fh;

	return $bytes;
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

subtest 'a digest that disagrees with its file' => sub {
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
		'a second keys block' => [
			qr{the description holds 2 keys blocks},
			<<'RC'
keys "keys" {
	org = fugubsd
}

keys "other" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}
RC
		],
		'an unknown setting of the keys block' => [
			qr{keys "keys" names the unknown setting orgg},
			<<'RC'
keys "keys" {
	org  = fugubsd
	orgg = fugubsd
}

key "fugubsd-1-release" {
	status = current
}
RC
		],
		'an expiry that RFC 3339 does not hold' => [
			qr{expires is 2027-09-07, which is not an RFC 3339},
			<<'RC'
keys "keys" {
	org     = fugubsd
	contact = mailto:security@fugubsd.org
	expires = 2027-09-07
}

key "fugubsd-1-release" {
	status = current
}
RC
		],
		'a key block with no keys block' => [
			qr{key "fugubsd-1-release" stands with no keys block},
			<<'RC'
key "fugubsd-1-release" {
	status = current
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

subtest 'a keys name that names no directory of its own' => sub {
	my %case = (
		'a solidus' => [ 'a/b', qr{holds a solidus} ],
		'one dot'   => [ '.',   qr{names a directory of the path} ],
		'two dots'  => [ '..',  qr{leaves the output directory} ],
		'the staging directory' =>
		    [ '.man', qr{is the staging directory of the build} ],
	);

	for my $name ( sort keys %case ) {
		my ( $word, $pattern ) = @{ $case{$name} };
		my $root = project(
			keys => { 'fugubsd-1-release.pub' => $SIGNIFY },
			rc   => <<"RC"
keys "$word" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}
RC
		);

		my ( $config, $reason ) = load($root);
		ok( !$config, "$name is refused" );
		like( $reason, $pattern, 'and the reason names it' );
	}
};

subtest 'a key directory that collides with a page' => sub {
	my $root = project( rc => <<'RC' );
page "keys" {
	title = Keys
	body  = index.body.html
}

keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status = current
}
RC

	my ( $config, $reason ) = load($root);
	ok( !$config, 'the description is refused' );
	like( $reason, qr{both become the same name in the output},
		'because a page and a directory cannot share one name' );
};

subtest 'an email that is not a local part and a domain' => sub {
	my $root = project( rc => <<'RC' );
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status = current
	email  = security-at-fugubsd.org
}
RC

	my ( $config, $reason ) = load($root);
	ok( !$config, 'the description is refused' );
	like( $reason, qr{which is not a local part and a domain},
		'and the reason names the shape' );
};

subtest 'an armored body that does not decode' => sub {
	# The guards of Fugu::KeyDir read the text of a block. They
	# hold the delimiters and the block type, and they decode
	# nothing, so a body with a broken checksum passes them.
	my $broken = $OPENPGP;
	$broken =~ s/^=\S+$/=AAAA/m;

	my $root = project(
		keys => {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $broken,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status = current
}
RC
	);

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $keys = App::FuguWeb::Keys->new( config => $config );
	ok( !$keys->generated, 'the key directory refuses to generate' );
	like( $keys->error, qr{checksum}, 'and the reason names the checksum' );
};

subtest 'an address whose keys are all retired' => sub {
	my $root = project( rc => <<'RC' );
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status = retired
	email  = security@fugubsd.org
}
RC

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	# gpg --locate-keys reads the file to encrypt a message, and a
	# retired key is the one key that must not answer that.
	my @wkd = grep { m{openpgpkey/hu/} } $config->key_paths;
	is( scalar @wkd, 0, 'the address serves no key' );

	my $keys      = App::FuguWeb::Keys->new( config => $config );
	my $generated = $keys->generated;
	ok( $generated, 'the key directory generates' ) or diag $keys->error;
	ok( !grep { m{openpgpkey/hu/} } keys %$generated,
		'and it writes no Web Key Directory file' );
	ok( !$generated->{'.well-known/openpgpkey/policy'},
		'and no policy file beside it' );
};

subtest 'a reference that climbs above the site root' => sub {
	my $root = project();
	spew( "$root/web/footer.body.html",
		qq{<p><a href="../../secret.txt">Up</a></p>\n} );

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	# A step above the root names no file of the output. A walk
	# that stopped at the root would read the reference as a link
	# that resolves.
	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;
	ok( ( grep { m{leaves the site} } @problems ),
		'the check reports it' )
	    or diag join "\n", @problems;
};

subtest 'a fingerprint of the wrong shape' => sub {
	my $root = project( rc => <<'RC' );
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status      = current
	fingerprint = abc
}
RC

	my ( $config, $reason ) = load($root);
	ok( !$config, 'the description is refused' );
	like( $reason, qr{fingerprint is abc, which is not 40 hexadecimal},
		'and the reason names the shape' );
};

subtest 'a symlink in the key directory' => sub {
	my $root = project();
	symlink '/etc/passwd', "$root/web/keys/fugubsd-9-release.pub"
	    or plan skip_all => 'cannot make a symlink here';

	my ( $config, $reason ) = load($root);
	ok( !$config, 'the description is refused' );
	like(
		$reason,
		qr{web/keys/fugubsd-9-release\.pub is a symlink},
		'because the build would publish what the link points at'
	);
};

subtest 'an armored block that is not a public key' => sub {
	my $private = $OPENPGP;
	$private =~ s/PGP PUBLIC KEY BLOCK/PGP PRIVATE KEY BLOCK/g;

	my $root = project(
		keys => {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $private,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status = current
}
RC
	);

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $keys = App::FuguWeb::Keys->new( config => $config );
	ok( !$keys->generated, 'the key directory refuses to generate' );
	like( $keys->error, qr{PRIVATE KEY BLOCK},
		'and the reason names the block' );

	# The guard must run before the first copy, or a failed build
	# leaves the private key in the output.
	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( !site( $config, $out )->build, 'the build fails' );
	ok( !-e "$out/keys/fugubsd-1-contact.asc",
		'and it copies no key into the output' );
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
	# published diff shows a change that nobody made. The compare
	# reads the bytes: two files of one length can differ.
	my %first = map { $_ => slurp("$out/$_") } tree($out);
	ok( site( $config, $out )->build, 'a second build succeeds' );
	my %second = map { $_ => slurp("$out/$_") } tree($out);
	is_deeply( \%second, \%first, 'and writes the same bytes' );
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
		'the key that the site dropped is gone' );
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
		'the check names a stray file below the root by its path' );
};

subtest 'the whole check run holds the key rules' => sub {
	my $root = project(
		files => {
			'web/keys/SHA256' => manifest(
				'fugubsd-1-release.pub' => "other bytes\n",
				'fugubsd-1-contact.asc' => $OPENPGP,
			)
		}
	);

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	# fuguweb check is what a publish workflow runs, so the key
	# rules must reach it and not only the class that holds them.
	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;
	ok(
		( grep { m{^keys/fugubsd-1-release\.pub: the manifest records} }
			@problems ),
		'the run reports a digest that disagrees with its file'
	) or diag join "\n", @problems;
};

subtest 'the chrome of a page below the root' => sub {
	my $root = project( rc => <<'RC' );
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status = current
}
RC

	# An absolute navigation entry names a place of its own, so
	# the step back must not stand in front of it.
	my $rc = slurp("$root/.fuguwebrc");
	$rc =~ s{nav "index\.html" \{\n\tlabel = Home\n\}}{$&\n\nnav "https://example.org/" {\n\tlabel = Elsewhere\n}};
	spew( "$root/.fuguwebrc", $rc );

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	my $page = slurp("$out/keys/index.html");
	like( $page, qr{href="https://example\.org/"},
		'an absolute navigation href keeps its own form' );
	unlike( $page, qr{href="\.\./https://},
		'and takes no step back in front of it' );
	like( $page, qr{href="\.\./index\.html"},
		'a relative one takes the step back' );

	# The generated page gets the checks of a page, so a broken
	# link of the chrome fails the check and never publishes.
	is( scalar App::FuguWeb::Check->new( config => $config, out => $out )
		->run,
		0, 'and the site passes its checks' );

	my @generated =
	    App::FuguWeb::Check->new( config => $config, out => $out )
	    ->generated_pages;
	is_deeply( \@generated, ['keys/index.html'],
		'the checks hold the generated page' );
};

subtest 'a link that only the generated page gets wrong' => sub {
	my $root = project();

	# The footer is project prose, and the build copies it into
	# every page. A relative link of the footer resolves against
	# the directory of the page that carries it. One href
	# therefore reaches the site from the root and misses from
	# keys/.
	spew( "$root/web/about.body.html", "<h1>About</h1>\n" );
	spew( "$root/web/footer.body.html",
		qq{<p><a href="about.html">About</a></p>\n} );

	my $rc    = slurp("$root/.fuguwebrc");
	my $added = $rc =~ s{^keys "keys"}{page "about.html" {\n\ttitle    = About\n\tbody     = about.body.html\n\tunlinked = yes\n}\n\nkeys "keys"}m;
	ok( $added, 'the fixture adds a page of the root' );
	spew( "$root/.fuguwebrc", $rc );

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;

	# Each page of the root carries the same href and resolves it,
	# so this problem belongs to the generated page alone.
	is_deeply(
		[@problems],
		['keys/index.html: about.html leads nowhere'],
		'the check reports the link of the generated page'
	) or diag join "\n", @problems;
};

subtest 'two keys of one address share one path' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'fugubsd-2-contact.asc' => $OPENPGP_TWO,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status = retired
	email  = security@fugubsd.org
}

key "fugubsd-2-contact" {
	status = current
	email  = security@fugubsd.org
}
RC
	);

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my @wkd = grep { m{openpgpkey/hu/} } $config->key_paths;
	is_deeply( \@wkd, [ '.well-known/openpgpkey/hu/' . WKD_HASH ],
		'the inventory names the address once' );

	my $keys      = App::FuguWeb::Keys->new( config => $config );
	my $generated = $keys->generated;
	ok( $generated, 'the key directory generates' ) or diag $keys->error;

	# One file holds both keys, so a rotation publishes the
	# current key and the retired one at one address. One file for
	# each key would publish the last one written only.
	# The file holds both keys, byte for byte, in publication
	# order. A length test would pass for one key of any size.
	my $binary = $generated->{ '.well-known/openpgpkey/hu/' . WKD_HASH };
	my ($current) = Fugu::OpenPGP->decode_armor($OPENPGP_TWO);
	my ($retired) = Fugu::OpenPGP->decode_armor($OPENPGP);

	is( $binary, $current . $retired,
		'the file holds the current key and then the retired one' );
};

subtest 'clean removes the whole tree' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );
	ok( -d "$out/keys", 'the key directory is there' );

	ok( site( $config, $out )->clean, 'the clean succeeds' );
	ok( !-e $out, 'and the whole tree is gone' );
};

subtest 'the build keeps a directory that no build made' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	# The output holds one flat directory of files, and the key
	# directory below it. Anything else belongs to whoever put it
	# there, so a build must leave it, however deep it sits.
	make_path("$out/photos/deep");
	spew( "$out/photos/holiday.jpg",   "mine\n" );
	spew( "$out/photos/deep/more.jpg", "mine\n" );

	ok( site( $config, $out )->build, 'a second build succeeds' );
	ok( -e "$out/photos/holiday.jpg", 'and it keeps the file' );
	ok( -e "$out/photos/deep/more.jpg", 'and the file below it' );
	ok( -d "$out/photos/deep",          'and the directory' );

	# The prune must never remove what the clean refuses to.
	ok( !site( $config, $out )->clean, 'the clean refuses the tree' );

	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;
	ok(
		( grep { m{^photos/holiday\.jpg: in the output} } @problems ),
		'and the check reports it'
	) or diag join "\n", @problems;
};

subtest 'the checks see an empty directory that no build made' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	ok( site( $config, $out )->build, 'the build succeeds' );

	mkdir "$out/archive" or die "Cannot make the directory: $!";

	# An empty directory is a leaf of the walk, so the checks and
	# the clean agree about the same tree.
	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;
	ok( ( grep { m{^archive: in the output} } @problems ),
		'the check reports it' )
	    or diag join "\n", @problems;

	ok( site( $config, $out )->build, 'a second build succeeds' );
	ok( -d "$out/archive", 'and the build keeps it' );
};

subtest 'list_tree walks the leaves and no symlink' => sub {
	my $dir = tempdir( CLEANUP => 1 );

	spew( "$dir/top.txt",           "a\n" );
	spew( "$dir/below/deep/one.txt", "b\n" );
	mkdir "$dir/empty" or die "Cannot make the directory: $!";

	my $linked = -e '/etc/hostname' ? '/etc/hostname' : '/etc/passwd';
	my $made = symlink $linked, "$dir/link";
	my $tree = symlink $dir . '/below', "$dir/tree";

	my $paths = App::FuguWeb::list_tree($dir);
	ok( $paths, 'the walk reads the directory' );

	my %found = map { $_ => 1 } @$paths;
	ok( $found{'top.txt'},            'a file of the top level' );
	ok( $found{'below/deep/one.txt'}, 'a file below it' );
	ok( $found{'empty'}, 'an empty directory is a leaf of its own' );

	SKIP: {
		skip 'cannot make a symlink here', 2 unless $made && $tree;

		ok( $found{'link'}, 'a symlink is one entry' );
		ok( $found{'tree'},
			'and a symlinked directory is one entry, not a walk' );
	}

	is( App::FuguWeb::list_tree("$dir/no-such-directory"),
		undef, 'a directory that it cannot read gives undef' );
};

# cli($root, @argv):
#	Run one command of the tool from the project root, with the
#	output captured, and return the exit code.
sub cli ( $root, @argv )
{
	my ( $out, $err ) = ( '', '' );

	my $here = Cwd::getcwd();
	chdir $root or die "Cannot chdir to $root: $!";

	open my $saved_out, '>&', \*STDOUT or die "Cannot save stdout: $!";
	open my $saved_err, '>&', \*STDERR or die "Cannot save stderr: $!";
	close STDOUT;
	close STDERR;
	open STDOUT, '>', \$out or die 'Cannot capture stdout';
	open STDERR, '>', \$err or die 'Cannot capture stderr';

	my $exit = eval { App::FuguWeb::CLI->run(@argv) };
	my $died = $@;

	close STDOUT;
	close STDERR;
	open STDOUT, '>&', $saved_out or die "Cannot restore stdout: $!";
	open STDERR, '>&', $saved_err or die "Cannot restore stderr: $!";

	chdir $here or die "Cannot chdir back: $!";
	die $died if $died;

	return ( $exit, $err );
}

subtest 'the clean command removes a key directory' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );
	ok( -d "$out/keys", 'the key directory is there' );

	# The command names --out, so it loads no description of its
	# own by the older rule. The description is what names the key
	# directory, and without it the clean refuses the whole site.
	my ( $exit, $err ) = cli( $root, 'clean', '--out', $out );
	is( $exit, 0, 'the clean succeeds' ) or diag $err;
	ok( !-e $out, 'and the whole tree is gone' );
};

subtest 'the clean command still refuses a tree that no build made' => sub {
	my $root = project();

	# A description that does not load must not stop the clean.
	# It is the command an operator reaches for when a description
	# is broken.
	spew( "$root/.fuguwebrc", "site = Example\nkeys \"keys\" {\n" );

	my $victim = "$root/victim";
	spew( "$victim/deep/keep.txt", "important\n" );

	my ( $exit, $err ) = cli( $root, 'clean', '--out', $victim );
	isnt( $exit, 0, 'the clean fails' );
	ok( -e "$victim/deep/keep.txt", 'and removes nothing' );
	like( $err, qr/refusing to remove it/, 'and says why' );
};

subtest 'clean refuses a tree that no build made' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	# A symlink below the root. The clean deletes a tree without
	# asking, so it must refuse anything that a build cannot have
	# written.
	symlink '/etc/passwd', "$out/keys/link"
	    or plan skip_all => 'cannot make a symlink here';

	ok( !site( $config, $out )->clean, 'the clean refuses' );
	ok( -e "$out/keys/fugubsd-1-release.pub", 'and removes nothing' );
};

subtest 'clean refuses a foreign target that holds a tree' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	# A --out that names another directory gets the strict rule.
	# The clean deletes without asking. A typed path must never
	# take the tree of somebody else with it, whatever the
	# description of this site happens to name.
	my $victim = tempdir( CLEANUP => 1 ) . '/victim';
	spew( "$victim/keys/deep/keep.txt", "important\n" );

	ok( !site( $config, $victim )->clean, 'the clean refuses' );
	ok( -e "$victim/keys/deep/keep.txt", 'and removes nothing' );

	# The same tree under the output directory of the description
	# belongs to the build, which owns that directory.
	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );
	ok( site( $config, $out )->clean, 'and the clean removes it' );
	ok( !-e $out, 'the whole tree is gone' );
};

subtest 'a description that drops its keys block' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );
	ok( -d "$out/keys", 'the key directory is there' );

	# A site that drops the whole block strands the published
	# tree. The build owns its output directory, so the clean must
	# still remove it. A tool that can neither prune nor clean its
	# own output is a tool that an operator cannot use.
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
RC

	my ( $bare, $why ) = load($root);
	ok( $bare, 'the smaller description loads' ) or diag $why;
	is( $bare->keys_dir, undef, 'and it names no key directory' );

	my @problems =
	    App::FuguWeb::Check->new( config => $bare, out => $out )->run;
	ok( ( grep { m{^keys/} } @problems ),
		'the check reports the stranded tree' );

	ok( site( $bare, $out )->clean, 'the clean removes the output' );
	ok( !-e $out, 'and the whole tree is gone' );
};

subtest 'the build refuses a symlink in the output' => sub {
	# The skip comes before the first assertion. A plan that
	# arrives after one turns a failed assertion into a pass.
	my $probe = tempdir( CLEANUP => 1 );
	plan skip_all => 'cannot make a symlink here'
	    unless symlink '/nonexistent', "$probe/link";

	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	# A dangling symlink is the dangerous one. Fugu::File->write
	# unlinks a path only when it exists, so an open would follow
	# the link and write the page outside the output directory.
	my $outside = tempdir( CLEANUP => 1 ) . '/pwned.html';
	unlink "$out/index.html";
	symlink $outside, "$out/index.html" or die "Cannot link: $!";

	ok( !site( $config, $out )->build, 'a second build refuses' );
	ok( !-e $outside, 'and it writes nothing through the link' );

	# The same rule guards the key directory, where a link would
	# take the published key material with it.
	unlink "$out/index.html";
	remove_tree("$out/.well-known");
	my $elsewhere = tempdir( CLEANUP => 1 ) . '/keys';
	symlink $elsewhere, "$out/.well-known" or die "Cannot link: $!";

	ok( !site( $config, $out )->build, 'a build with a linked tree fails' );
	ok( !-e $elsewhere, 'and it writes no key through the link' );
};

subtest 'an output path that ends in a slash' => sub {
	my $root = project();

	# File::Find writes the root of a walk without a trailing
	# slash, so a path that carries one would cut every relative
	# path one character short. The clean would then read its own
	# answer as 'nothing to refuse'.
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	my $victim = tempdir( CLEANUP => 1 ) . '/victim';
	spew( "$victim/precious/data.txt", "data\n" );

	ok( !site( $config, "$victim/" )->clean, 'the clean refuses' );
	ok( -e "$victim/precious/data.txt", 'and removes nothing' );
};

done_testing();
