#!/usr/bin/env perl
# ex:ts=8 sw=4:
# App::FuguWeb::Keys: the description blocks, the published tree, and
# every rule of the check.
#
# The test builds each key directory in a File::Temp directory, and it
# never reads the repository. The key material is a fixture, so the
# test needs no signify(1). The fixture holds one binding that gpg(1)
# made, and every assertion which reads that binding needs gpg(1).
# Each certificate of the fixture reads with no command. One subtest
# makes a certificate that expires soon, because no fixed date can
# stand 30 days from the day of the run, and openssl(1) makes that
# one. Its skip stands before the first assertion of the subtest.
#
# A few subtests drive the real command through App::FuguWeb::CLI,
# which renders. Those need the renderers, so each one skips without
# them. Every skip sits inside its subtest. A plan skip_all comes
# before the first assertion, and a SKIP block guards an assertion
# that follows one.

use v5.36;
use Test::More;
use FindBin qw($RealBin);
use lib "$RealBin/../../lib";
use Digest::SHA ();
use File::Path qw(make_path remove_tree);
use Cwd ();
use File::Temp qw(tempdir);
use POSIX ();

use_ok('App::FuguWeb::Check');
use_ok('App::FuguWeb::Config');
use_ok('App::FuguWeb::Keys');
use_ok('App::FuguWeb::Render');
use_ok('Fugu::OpenPGP');
use_ok('Fugu::X509');
use_ok('App::FuguWeb::CLI');
use_ok('App::FuguWeb::Site');
use_ok('Fugu::Log');

# Two real signify public keys, and a real OpenPGP public key. Each
# one is a fixture of this file: signify(1) made both signify pairs,
# and gpg(1) exported the armored key.
#
# The root key is the root of trust of the directory, per WEB-TRUST-1.
# Its purpose word is root, and the release key is a subordinate key.
my $ROOT = <<'KEY';
untrusted comment: fugubsd-1-root public key
RWQ9Jj8uRVle/Px7eFON/VRu4xaO1j1KlTo0EBVXNqKuETmYBtLGNLvr
KEY

my $SIGNIFY = <<'KEY';
untrusted comment: fugubsd-1-release public key
RWTm3yAPqZL2WmdfUi65cf2UcgjKGqyICHwk2y6sZTKSTY1GZFKvCs2W
KEY

# The binding of the release key over the root key file: the private
# half of the release key signed the bytes of fugubsd-1-root.pub. A
# current signer targets the root, so the retention rule takes it.
my $BINDING = <<'SIG';
untrusted comment: verify with fugubsd-1-release.pub
RWTm3yAPqZL2WuoEneZq0cxgMzo4nBYewBJxzd78c2N+2iXrlH1DGngZc6o+2WsA8qQb8t+ZXCDB4gc+3itRk1J4ziPhjhE8NAw=
SIG

# The binding of the root key over the release key file. The signature
# verifies, and the retention rule refuses it: a current signer must
# target the root, and this one targets a subordinate key.
my $OFF_ROOT = <<'SIG';
untrusted comment: verify with fugubsd-1-root.pub
RWQ9Jj8uRVle/NhGKA7te3yKRrH01B7ztDFIzNBYaiJhp/JD6wF0Ig5Zozg7lHEp0uz247WVOrP1yY/tA+ZN8hMPBQAE5LXbeAE=
SIG

my $OPENPGP = <<'KEY';
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEaqZfLBYJKwYBBAHaRw8BAQdA5hUJ3Jf2vBNc/zFJkbdMbqRFVAlWMknu6xmz
rJLnZv+0FjxzZWN1cml0eUBmdWd1YnNkLm9yZz6IrwQTFgoAVxYhBDuMFQzQERVa
J4mulBtFpUpIa5yMBQJqpl8sGxSAAAAAAAQADm1hbnUyLDIuNSsxLjEyLDAsMwIb
AwULCQgHAgIiAgYVCgkICwIEFgIDAQIeBwIXgAAKCRAbRaVKSGucjCtfAP90OU9k
JYLM5VVG7U8rmHfYYSa5b0hP99P8lgy//QFYvQD+KXZHLiWd8TA0KOxtX83Ln+zK
E977ue1+LuwGUUihAAi4OARqpl8tEgorBgEEAZdVAQUBAQdAvvPWTJlgJeMVoDko
9tl6RAmuXBu/gfDZo91xSjKX4z0DAQgHiJQEGBYKADwWIQQ7jBUM0BEVWieJrpQb
RaVKSGucjAUCaqZfLRsUgAAAAAAEAA5tYW51MiwyLjUrMS4xMiwwLDMCGwwACgkQ
G0WlSkhrnIzK3gEAxW4D8dCHlTiyH44t6CPgWnxMewJaxh5eQKshUzEIDUcBAPNB
5eiF/D58FL3uyUuvJZwKkqNxH9dl/6gGS1AkNYoJ
=6soI
-----END PGP PUBLIC KEY BLOCK-----
KEY

# The binding of the contact key over the root key file: the private
# half of that OpenPGP key signed the bytes of fugubsd-1-root.pub.
# WEB-TRUST-3 asks every key in force for one, and gpg(1) made this
# one. A host with no gpg(1) cannot read it, so each subtest that
# holds the whole directory to the checks skips without the command.
my $CONTACT_BINDING = <<'SIG';
-----BEGIN PGP SIGNATURE-----

iJEEABYKADkWIQQ7jBUM0BEVWieJrpQbRaVKSGucjAUCaqZfLhsUgAAAAAAEAA5t
YW51MiwyLjUrMS4xMiwwLDMACgkQG0WlSkhrnIyJ4AEAzspXUwxsu3/8yV3nh77A
Oezq9ghSlhz7h5SW7ka15cYA/RC1NUNM/Ym8tg18GreIzW7U+XcEDxgOLe0kMyoy
dHoK
=lCvc
-----END PGP SIGNATURE-----
SIG

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
	FINGERPRINT => '3B8C150CD011155A2789AE941B45A54A486B9C8C',
	WKD_HASH    => 't5s8ztdbon8yzntexy6oz5y48etqsnbb',
};

# A real signify signature. The site build verifies nothing: a site
# that verified its own manifest would prove nothing. It reads the
# shape, because a file of another shape fails at every consumer
# install and never here. signify-openbsd(1) wrote these bytes.
my $SIGNATURE = <<'SIG';
untrusted comment: verify with k.pub
RWS/n+2mbBbQjaszJlHbcECAmX6zY46E8MrxS6vpDXtY33UrTfBBVbrutfEVICOlrSP+m3H++WREZe3nc18vW/2QkeczyJcMFAo=
SIG

# Three real X.509 certificates. openssl(1) made each one, and the
# test reads them with Fugu::X509, which needs no command. Each pair
# of dates is fixed, so no assertion below depends on the day of the
# run.
#
# This certificate is valid from 2020 to 2999. It is therefore valid
# on every day that this test runs, and it never reaches the 30-day
# report of WEB-X509-6.
my $CERT = <<'PEM';
-----BEGIN CERTIFICATE-----
MIIB6TCCAY+gAwIBAgIUS6qvjtHt4Hjk53+pwP4db2ngz8gwCgYIKoZIzj0EAwIw
STELMAkGA1UEBhMCU0UxEDAOBgNVBAoMB0V4YW1wbGUxDzANBgNVBAsMBlRFQU1J
RDEXMBUGA1UEAwwORXhhbXBsZSBTaWduZXIwIBcNMjAwMTAxMDAwMDAwWhgPMjk5
OTEyMzEyMzU5NTlaMEkxCzAJBgNVBAYTAlNFMRAwDgYDVQQKDAdFeGFtcGxlMQ8w
DQYDVQQLDAZURUFNSUQxFzAVBgNVBAMMDkV4YW1wbGUgU2lnbmVyMFkwEwYHKoZI
zj0CAQYIKoZIzj0DAQcDQgAEkBYDhRjDnbaRDy23zerOgcJj52sSdgJYKVob+hrX
4XmRzgOQ4V429n0WfO2KcL828VGFl4++u/7Cy77q9kCMOKNTMFEwHQYDVR0OBBYE
FCItjDYuouLybpxUm/M2H28FZ/RMMB8GA1UdIwQYMBaAFCItjDYuouLybpxUm/M2
H28FZ/RMMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIgI4A0pA8F
p/lWpQrxI9dgkh/Zjfi620AIxPe2likNuLYCIQDINQaYXeWTX6DSyyYB9WuLLAJg
lQy/3EEqC1pkyGu30w==
-----END CERTIFICATE-----
PEM

# The SHA-256 of the DER form of the certificate above, per
# WEB-X509-4, and the subject that it carries. Fugu::X509 answers the
# subject as a hash of attribute type to value, and the human page
# writes one line of it, sorted by the type.
use constant {
	CERT_FINGERPRINT =>
	    'C3A6AAE7262F644D2F2FFD2ADCB34F645A7387CD101A398A0FD0E1361AF3BE72',
	CERT_SUBJECT => 'C=SE, CN=Example Signer, O=Example, OU=TEAMID',
};

# A certificate whose validity passed, and one whose validity has not
# started. The check of WEB-X509-6 needs both sides of the window.
my $EXPIRED_CERT = <<'PEM';
-----BEGIN CERTIFICATE-----
MIIBiDCCAS2gAwIBAgIUJ5GFVkr4fBWxm93QDpQvREErItUwCgYIKoZIzj0EAwIw
GTEXMBUGA1UEAwwORXhwaXJlZCBTaWduZXIwHhcNMDAwMTAxMDAwMDAwWhcNMDEw
MTAxMDAwMDAwWjAZMRcwFQYDVQQDDA5FeHBpcmVkIFNpZ25lcjBZMBMGByqGSM49
AgEGCCqGSM49AwEHA0IABNZAfkRWwW4Qkk8mZ24Q0dC5slDv7cXMsDPhqOhIlYzi
dJU6fykjIMxs52aiGdMwmhjQqUD61DVyMeVM987lbiijUzBRMB0GA1UdDgQWBBR7
IWLvo05TUsUhw1mcZEZLsD9y5zAfBgNVHSMEGDAWgBR7IWLvo05TUsUhw1mcZEZL
sD9y5zAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0kAMEYCIQD/6lV3cyO2
KVGnbr3hjQzk9DtTtBMSUCZutBaz6scxwQIhAMs+VQcRGwWdxUSJogu2xZiJ5ULv
5Bkp9pTtMhiETpqo
-----END CERTIFICATE-----
PEM

my $FUTURE_CERT = <<'PEM';
-----BEGIN CERTIFICATE-----
MIIBiTCCAS+gAwIBAgIUKa+Zc5yYip9wOVOCqLJuGp/ElgMwCgYIKoZIzj0EAwIw
GDEWMBQGA1UEAwwNRnV0dXJlIFNpZ25lcjAiGA8yMDkwMDEwMTAwMDAwMFoYDzIw
OTkwMTAxMDAwMDAwWjAYMRYwFAYDVQQDDA1GdXR1cmUgU2lnbmVyMFkwEwYHKoZI
zj0CAQYIKoZIzj0DAQcDQgAEz9/pBsXt+/LvEY09c+LgeUrS9LqEeJWQ0mjqPY7u
slW5HqVPDApMq2Xy/YGFahCU5cpEqEWLVVX1Gbh3+glts6NTMFEwHQYDVR0OBBYE
FE+oSPP6edfPDIXLdKMRnEqng3qfMB8GA1UdIwQYMBaAFE+oSPP6edfPDIXLdKMR
nEqng3qfMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIhAP8/q0L4
fIc1AwRB7cWF0XoOvLSRyXGqco9u4PYUHKsFAiAxjJhgSoHeuquUS+4lKU0g1TOw
7SFgeedO/WnmwuxElQ==
-----END CERTIFICATE-----
PEM

my $KEYS_BLOCK = <<'RC';
keys "keys" {
	org     = fugubsd
	contact = mailto:security@fugubsd.org
	expires = 2027-09-07T00:00:00Z
	url     = https://www.fugubsd.org/keys
}

key "fugubsd-1-root" {
	status = current
	since  = 2026-09-07
}

key "fugubsd-1-release" {
	status = current
	since  = 2026-09-07
}

key "fugubsd-1-contact" {
	status      = current
	since       = 2026-09-07
	email       = security@fugubsd.org
	fingerprint = 3B8C150CD011155A2789AE941B45A54A486B9C8C
}
RC

# WEB-TRUST-9. The key directory of the fixture holds a binding of the
# contact key, and gpg(1) verifies one of that type. A host with no
# gpg(1) therefore reads one problem in a good directory, and each
# assertion that reads the whole report skips there.
my $GPG = Fugu::OpenPGP->new->is_available;

# The program that the renderer probe of a fixture runs. A fixture
# names a renderer and calls none, so the name must be a program that
# stands. The probe takes the first path of the list that is
# executable.
my $TRUE = ( grep { -x } qw(/usr/bin/true /bin/true) )[0];

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
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'fugubsd-1-root.pub.fugubsd-1-release.sig' => $BINDING,
			'fugubsd-1-root.pub.fugubsd-1-contact.asc' =>
			    $CONTACT_BINDING,
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

# keyless():
#	The same small project with no keys block and no key
#	directory. A description that publishes no key owns no path of
#	one, and the well-known names are the trap: a site of another
#	maker holds security.txt too.
sub keyless ()
{
	my $root = tempdir( CLEANUP => 1 );

	spew( "$root/web/index.body.html", "<h1>Home</h1>\n" );
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

	# WEB-KEYS-16. The inventory names each binding file beside
	# each key file, so the build and the checks read one list.
	my %path = map { $_ => 1 } $config->key_paths;
	for my $name (
		'keys/fugubsd-1-root.pub',    'keys/fugubsd-1-release.pub',
		'keys/fugubsd-1-contact.asc', 'keys/SHA256',
		'keys/SHA256.sig',            'keys/KEYS',
		'keys/index.html',
		'keys/fugubsd-1-root.pub.fugubsd-1-release.sig',
		'keys/fugubsd-1-root.pub.fugubsd-1-contact.asc',
		'.well-known/openpgpkey/hu/' . WKD_HASH,
		'.well-known/openpgpkey/policy',
		'.well-known/security.txt'
	    )
	{
		ok( $path{$name}, "the inventory names $name" );
	}

	is( scalar keys %path, 12, 'and it names nothing else' );

	my %inventory = map { $_ => 1 } $config->inventory;
	ok( $inventory{'keys/KEYS'}, 'the inventory of the site holds them' );
	ok( $inventory{'index.html'}, 'beside the pages of the description' );
};

subtest 'the key blocks' => sub {
	my ( $config, $reason ) = load( project() );
	ok( $config, 'the description loads' ) or diag $reason;

	my ($signify) =
	    grep { $_->{purpose} eq 'release' } $config->site_keys;
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

	# A binding carries no block: its name holds the target, the
	# signer and the type, and Fugu::KeyDir parses it. Each key in
	# force holds one over the root, per WEB-TRUST-3.
	my %binding = map { $_->{name} => $_ } $config->site_bindings;
	is( scalar keys %binding, 2, 'the directory holds two bindings' );

	my $by_signify = $binding{'fugubsd-1-root.pub.fugubsd-1-release.sig'};
	is( $by_signify->{target}, 'fugubsd-1-root.pub',    'the target' );
	is( $by_signify->{signer}, 'fugubsd-1-release.pub', 'the signer' );
	is( $by_signify->{type},   'signify',               'the signer type' );

	my $by_openpgp = $binding{'fugubsd-1-root.pub.fugubsd-1-contact.asc'};
	is( $by_openpgp->{target}, 'fugubsd-1-root.pub',
		'the target of the second' );
	is( $by_openpgp->{signer}, 'fugubsd-1-contact.asc', 'its signer' );
	is( $by_openpgp->{type},   'openpgp', 'and its signer type' );
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

	# WEB-KEYS-13 names every column of the page, so the test does
	# too. A row that lost six columns passed before.
	my $page = $generated->{'keys/index.html'};
	for my $head (
		'Key',         'Purpose', 'Serial',   'Type',
		'Status',      'Fingerprint', 'Subject', 'Validity',
		'Since',       'Until',   'Bindings'
	    )
	{
		like( $page, qr{<th>\Q$head\E</th>},
			"the page names the $head column" );
	}

	# The subject and the validity cells belong to a certificate,
	# so a key of another type leaves each one empty.
	like(
		$page,
		qr{<td>release</td><td>1</td><td>signify</td><td>current</td><td></td><td></td><td></td><td>2026-09-07</td><td></td>},
		'and a signify row holds each value in order'
	);
	like(
		$page,
		qr{<td>contact</td><td>1</td><td>openpgp</td><td>current</td><td>\Q@{[FINGERPRINT]}\E</td>},
		'and an OpenPGP row holds its fingerprint'
	);

	like( $page, qr{<title>Keys },     'the index page has a title' );
	like( $page, qr{href="\.\./style\.css"},
		'and it steps back to the stylesheet of the root' );
	like( $page, qr{href="\.\./index\.html"},
		'and back to the entry page' );
	like( $page, qr{href="fugubsd-1-release\.pub"},
		'and it links each key beside it' );
	like( $page, qr{<td>release</td>}, 'and it names each purpose' );

	# WEB-TRUST-11. The row of a key lists each binding that names
	# it, with the signer and a link to the file. A reader of one
	# key thus sees every key that attests it.
	like( $page, qr{<th>Bindings</th>}, 'the page names the binding column' );
	like(
		$page,
		qr{<td><a href="fugubsd-1-root\.pub\.fugubsd-1-contact\.asc">fugubsd-1-contact</a>, <a href="fugubsd-1-root\.pub\.fugubsd-1-release\.sig">fugubsd-1-release</a></td>},
		'and the row of the root lists each binding that names it'
	);

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
	plan skip_all => 'gpg(1) is not installed' unless $GPG;

	is( problems( project() ), '', 'nothing to report' );
};

# WEB-TRUST-1. One signify key of the directory is the root of trust,
# and its purpose word is root. A directory with no such key gives a
# consumer no anchor to pin, and every binding of it names a target
# that nothing vouches for.
subtest 'a directory with keys and no root' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
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

	like(
		problems($root),
		qr{^keys: it holds no current key of the purpose root}m,
		'the check names the purpose'
	);
};

# WEB-TRUST-1. The root of trust is a signify key, per D-02. One line
# holds such a key, so a consumer pins it with one line of its own.
subtest 'a root key that is no signify key' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.asc'    => $OPENPGP,
			'fugubsd-1-release.pub' => $SIGNIFY,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-release" {
	status = current
}
RC
	);

	like(
		problems($root),
		qr{^keys/fugubsd-1-root\.asc: the root key is a openpgp key}m,
		'the check names the type'
	);
};

# WEB-TRUST-9. A binding that no key made proves nothing, so the check
# verifies each one against the public key of its signer. The signify
# verifier of the Fugu library needs no command.
subtest 'a binding that its signer does not verify' => sub {

	# The bytes are a real signature, and the root key made them.
	# The name says that the release key made them, so the walk
	# pins the release key and the check fails.
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-root.pub.fugubsd-1-release.sig' => $OFF_ROOT,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-release" {
	status = current
}
RC
	);

	like(
		problems($root),
		qr{^keys/fugubsd-1-root\.pub\.fugubsd-1-release\.sig: .*no key verified}ms,
		'the check names the binding'
	);
};

# WEB-TRUST-9. A signify binding needs no command, and a binding of
# another type needs the command of that type. An absent command
# leaves a binding that nothing read, so the check reports the host.
subtest 'an absent command for a binding type of the directory' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'fugubsd-1-root.pub.fugubsd-1-release.sig' => $BINDING,
			'fugubsd-1-root.pub.fugubsd-1-contact.asc' =>
			    "-----BEGIN PGP SIGNATURE-----\n\n-----END PGP SIGNATURE-----\n",
		}
	);

	my $found = do {
		local $ENV{PATH} = '/nonexistent';
		problems($root);
	};

	like(
		$found,
		qr{^keys/fugubsd-1-root\.pub\.fugubsd-1-contact\.asc: .*gpg}m,
		'the check names the binding and the command'
	);

	# The signify binding beside it needs no command, so the run
	# reports one problem and not two.
	unlike( $found, qr{fugubsd-1-release\.sig},
		'and the signify binding verifies without one' );
};

# WEB-TRUST-10. A signer that is current or next must target the root,
# so each key in force attests the one anchor. This binding verifies,
# and the retention rule is what refuses it.
subtest 'a binding that breaks the retention rule' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-release.pub.fugubsd-1-root.sig' => $OFF_ROOT,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-release" {
	status = current
}
RC
	);

	like(
		problems($root),
		qr{must target the root key fugubsd-1-root\.pub},
		'the check names the rule'
	);
};

# WEB-TRUST-3. Each current key and each next key of a subordinate
# purpose holds one binding over the public key file of the current
# root. That signature proves that the holder of the root also holds
# the subordinate key, so a key without one publishes an unproved
# claim.
subtest 'a key in force that holds no binding over the root' => sub {

	# A directory that holds no binding at all is the first case:
	# every rule of a binding must read the key set, and never the
	# bindings alone.
	my $bare = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-release" {
	status = current
}
RC
	);

	my $found = problems($bare);
	like(
		$found,
		qr{^keys/fugubsd-1-release\.pub: the current key holds no binding over the current root key fugubsd-1-root\.pub$}m,
		'the check names the key, its status and the root'
	);
	unlike( $found, qr{^keys/fugubsd-1-root\.pub: the current key holds no}m,
		'and the root binds to nothing, because it is the anchor' );

	# The second case: one key of the purpose holds its binding,
	# and the next key of that purpose holds none. The two key
	# files hold one key body, so the one binding fixture verifies
	# under the name of its signer.
	my $pending = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-2-release.pub' => $SIGNIFY,
			'fugubsd-1-root.pub.fugubsd-1-release.sig' => $BINDING,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-2-release" {
	status = next
}
RC
	);

	$found = problems($pending);
	like(
		$found,
		qr{^keys/fugubsd-2-release\.pub: the next key holds no binding}m,
		'a next key needs one as a current key does'
	);
	unlike( $found, qr{^keys/fugubsd-1-release\.pub: the current key holds no}m,
		'and the key that holds one is no problem' );
};

# WEB-KEYS-18. A binding needs no key block, and the directory must
# hold its target and its signer. A binding over a key that the site
# does not publish verifies nothing at a consumer.
subtest 'a binding that names a key of no block' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'fugubsd-9-root.pub.fugubsd-1-release.sig' => $BINDING,
		}
	);

	like(
		problems($root),
		qr{^keys/fugubsd-9-root\.pub\.fugubsd-1-release\.sig: it names the target fugubsd-9-root\.pub, and no key block names it}m,
		'the check names the target'
	);
};

# WEB-KEYS-19. A name of the directory matches the key pattern or the
# binding pattern, and nothing else.
subtest 'a binding name of another organization' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'fugubsd-1-root.pub.other-1-release.sig' => $BINDING,
		}
	);

	like(
		problems($root),
		qr{^keys/fugubsd-1-root\.pub\.other-1-release\.sig: }m,
		'the check names the file'
	);
};

subtest 'a key file that no block names' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'fugubsd-2-release.pub' => $SIGNIFY,
			'fugubsd-1-root.pub.fugubsd-1-release.sig' => $BINDING,
		}
	);

	like( problems($root), qr{^keys/fugubsd-2-release\.pub: no key block},
		'the check names the file' );
};

subtest 'a name that the pattern does not match' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'notes.txt'             => "a note\n",
			'fugubsd-1-root.pub.fugubsd-1-release.sig' => $BINDING,
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
				'fugubsd-1-root.pub'    => $ROOT,
				'fugubsd-1-release.pub' => "other bytes\n",
				'fugubsd-1-contact.asc' => $OPENPGP,
				'fugubsd-1-root.pub.fugubsd-1-release.sig' =>
				    $BINDING,
			)
		}
	);

	like(
		problems($root),
		qr{^keys/fugubsd-1-release\.pub: the manifest records \w+, and the file digests to}m,
		'the check names both digests'
	);
};

# WEB-KEYS-21 and WEB-TRUST-6. The manifest pins the bytes of every
# binding file too, so a consumer that fetched a forged binding reads
# a digest that disagrees with it.
subtest 'a digest that disagrees with a binding' => sub {
	my $root = project(
		files => {
			'web/keys/SHA256' => manifest(
				'fugubsd-1-root.pub'    => $ROOT,
				'fugubsd-1-release.pub' => $SIGNIFY,
				'fugubsd-1-contact.asc' => $OPENPGP,
				'fugubsd-1-root.pub.fugubsd-1-release.sig' =>
				    "other bytes\n",
			)
		}
	);

	like(
		problems($root),
		qr{^keys/fugubsd-1-root\.pub\.fugubsd-1-release\.sig: the manifest records \w+, and the file digests to}m,
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
				'fugubsd-1-root.pub'    => $ROOT,
				'fugubsd-1-release.pub' => $SIGNIFY,
				'fugubsd-1-contact.asc' => $OPENPGP,
				'fugubsd-9-release.pub' => $SIGNIFY,
				'fugubsd-1-root.pub.fugubsd-1-release.sig' =>
				    $BINDING,
			)
		}
	);

	like(
		problems($root),
		qr{^keys/SHA256: it names fugubsd-9-release\.pub, which is no key and no binding}m,
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

# WEB-X509-5 and WEB-KEYS-13. The human page names the subject and the
# validity dates of a certificate beside its fingerprint. A reader of
# the page compares the subject with what a signed binary reports, and
# the subject holds across a renewal that changes the fingerprint.
#
# WEB-X509-8. The KEYS file and the Web Key Directory each serve an
# OpenPGP reader, so both skip a certificate.
subtest 'the page of a certificate' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-contact.asc' => $OPENPGP,
			'fugubsd-1-sign.pem'    => $CERT,
		},
		rc => <<"RC"
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-contact" {
	status = current
	email  = security\@fugubsd.org
}

key "fugubsd-1-sign" {
	status      = current
	fingerprint = @{[CERT_FINGERPRINT]}
}
RC
	);

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;
	return unless $config;

	my $keys      = App::FuguWeb::Keys->new( config => $config );
	my $generated = $keys->generated;
	ok( $generated, 'the key directory generates' ) or diag $keys->error;
	return unless $generated;

	my $page = $generated->{'keys/index.html'};
	like(
		$page,
		qr{<td>sign</td><td>1</td><td>x509</td><td>current</td><td>\Q@{[CERT_FINGERPRINT]}\E</td><td>\Q@{[CERT_SUBJECT]}\E</td><td>2020-01-01 to 2999-12-31</td>},
		'the row of the certificate holds each value in order'
	);

	# gpg --import reads the KEYS file, and gpg --locate-keys
	# reads the Web Key Directory. Neither one reads a
	# certificate.
	unlike( $generated->{'keys/KEYS'}, qr{fugubsd-1-sign},
		'the KEYS file skips the certificate' );
	is_deeply(
		[ grep { m{openpgpkey/hu/} } sort keys %$generated ],
		[ '.well-known/openpgpkey/hu/' . WKD_HASH ],
		'and the Web Key Directory serves the OpenPGP address alone'
	);
};

# WEB-KEYS-22 and WEB-X509-4. The declared fingerprint of a
# certificate is the SHA-256 of its DER form, and the check holds it
# to the one that the bytes give.
subtest 'a fingerprint that the certificate does not give' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub' => $ROOT,
			'fugubsd-1-sign.pem' => $CERT,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-sign" {
	status      = current
	fingerprint = 0000000000000000000000000000000000000000000000000000000000000000
}
RC
	);

	like(
		problems($root),
		qr{^keys/fugubsd-1-sign\.pem: the description declares 0{64}, and the key gives \Q@{[CERT_FINGERPRINT]}\E$}m,
		'the check names both fingerprints'
	);
};

# WEB-KEYS-7 and WEB-X509-4. A key block of a certificate takes an
# optional fingerprint of 64 hexadecimal characters. It takes no
# email, because a certificate carries no user id. The width comes
# from the type: a check that took the width of an OpenPGP key would
# pass 40 characters of a SHA-256.
subtest 'a key block of a certificate that the loader refuses' => sub {
	my %case = (
		'an email on a certificate' => [
			qr{key "fugubsd-1-sign" names email, and fugubsd-1-sign\.pem is a x509 key},
			"\temail = x\@example.org\n",
		],
		'a fingerprint of 40 characters' => [
			qr{fingerprint is 0{40}, which is not 64 hexadecimal characters},
			"\tfingerprint = " . ( '0' x 40 ) . "\n",
		],
	);

	for my $name ( sort keys %case ) {
		my ( $pattern, $setting ) = @{ $case{$name} };

		my $root = project(
			keys => {
				'fugubsd-1-root.pub' => $ROOT,
				'fugubsd-1-sign.pem' => $CERT,
			},
			rc => <<"RC"
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-sign" {
	status = current
$setting}
RC
		);

		my ( $config, $reason ) = load($root);
		ok( !$config, "$name is refused" );
		like( $reason, $pattern, 'and the reason names it' );
	}
};

# WEB-X509-1. The key file must hold one PEM certificate. The reader
# takes one CERTIFICATE block, so a private key and a second block
# each fail it. A directory that held a certificate and its private
# key in one file would publish that key, and the operator splits the
# two.
#
# The delimiter of the private key is built and never written, because
# the secret gate reads this file and a block of that name is what it
# looks for.
subtest 'a pem file that is not one certificate' => sub {
	my $block = join ' ', 'PRIVATE', 'KEY';
	my %case = (
		'a private key block' => [
			"-----BEGIN $block-----\n"
			    . "bm90IGEgY2VydGlmaWNhdGU=\n"
			    . "-----END $block-----\n",
			qr{holds a \Q$block\E block, and this method takes a CERTIFICATE block},
		],
		'a second certificate block' => [
			$CERT . $CERT,
			qr{holds 2 CERTIFICATE blocks, and this method takes one},
		],
	);

	for my $name ( sort keys %case ) {
		my ( $bytes, $pattern ) = @{ $case{$name} };

		my $root = project(
			keys => {
				'fugubsd-1-root.pub' => $ROOT,
				'fugubsd-1-sign.pem' => $bytes,
			},
			rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-sign" {
	status = current
}
RC
		);

		my ( $config, $reason ) = load($root);
		ok( $config, "$name loads" ) or diag $reason;
		next unless $config;

		my $keys = App::FuguWeb::Keys->new( config => $config );
		ok( !$keys->generated, "and $name is refused" );
		like( $keys->error, qr{^fugubsd-1-sign\.pem: the text $pattern},
			'and the reason names the file and the fault' );

		my $out = "$root/out";
		ok( !site( $config, $out )->build, 'the build fails' );
		ok( !-e "$out/keys/fugubsd-1-sign.pem",
			'and it copies no key at all' );
	}
};

# WEB-X509-6. The check reports a current or next certificate whose
# notAfter has passed, and one whose notBefore has not come. Each
# fixture holds a fixed pair of dates, so the answer stands on every
# day and at every hour.
subtest 'a certificate that is not valid today' => sub {
	my $root = project(
		keys => {
			'fugubsd-1-root.pub'   => $ROOT,
			'fugubsd-1-sign.pem'   => $EXPIRED_CERT,
			'fugubsd-1-notary.pem' => $FUTURE_CERT,
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-sign" {
	status = current
}

key "fugubsd-1-notary" {
	status = current
}
RC
	);

	my $found = problems($root);
	like(
		$found,
		qr{^keys/fugubsd-1-sign\.pem: the current key expired on 2001-01-01$}m,
		'the check names the file and the date of the expiry'
	);
	like(
		$found,
		qr{^keys/fugubsd-1-notary\.pem: the current key is not valid before 2090-01-01$}m,
		'and the file and the date of a validity that has not started'
	);
};

# WEB-X509-6. The check reports a current certificate that expires
# within 30 days, when its purpose holds no next key. One rotation
# runs in two steps, and the consumers need the gap between them.
#
# No fixed date stands 30 days from the day of the run, so openssl(1)
# makes each certificate here. It writes notBefore at the current
# second and notAfter that many days later. A certificate of 30 days
# therefore stands inside the bar at every hour, and one of 32 days
# stands outside it.
subtest 'a certificate that expires soon' => sub {
	my $x509 = Fugu::X509->new;
	plan skip_all => 'openssl(1) is not installed'
	    unless $x509->is_available;

	my $work = tempdir( CLEANUP => 1 );
	my %pem;
	for my $case ( [ sign => 30 ], [ notary => 32 ] ) {
		my ( $purpose, $days ) = @$case;

		$x509->generate(
			subject => "/CN=Example $purpose",
			days    => $days,
			public  => "$work/$purpose.pem",
			secret  => "$work/$purpose.key",
		) or die "the $purpose certificate failed: "
		    . $x509->error . "\n";
		$pem{$purpose} = slurp("$work/$purpose.pem");
	}

	my $root = project(
		keys => {
			'fugubsd-1-root.pub'   => $ROOT,
			'fugubsd-1-sign.pem'   => $pem{sign},
			'fugubsd-1-notary.pem' => $pem{notary},
		},
		rc => <<'RC'
keys "keys" {
	org = fugubsd
}

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-sign" {
	status = current
}

key "fugubsd-1-notary" {
	status = current
}
RC
	);

	# The date comes from the certificate itself, so the assertion
	# reads no clock of its own.
	my $expiry = $x509->parse( $x509->decode_pem( $pem{sign} ) );
	my $date = POSIX::strftime( '%Y-%m-%d', gmtime $expiry->{not_after} );

	my $found = problems($root);
	like(
		$found,
		qr{^keys/fugubsd-1-sign\.pem: the current key expires on \Q$date\E, and the purpose sign holds no next key$}m,
		'the check names the file, the date and the purpose'
	);
	unlike( $found, qr{fugubsd-1-notary\.pem: the current key expires},
		'and a certificate outside the bar adds none' );
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

subtest 'a key directory that collides with the stylesheet' => sub {
	# The guard reads the whole inventory and not the pages, so
	# every name that the output takes gets it. The stylesheet is
	# the one such name that no block declares.
	my $root = project( rc => <<'RC' );
keys "style.css" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}

key "fugubsd-1-contact" {
	status = current
}
RC

	rename "$root/web/keys", "$root/web/style.css"
	    or die "Cannot rename: $!";

	my ( $config, $reason ) = load($root);
	ok( !$config, 'the description is refused' );
	like( $reason, qr{both become the same name in the output},
		'because the stylesheet takes that name' );
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
	ok( ( grep { m{names no page of the site} } @problems ),
		'the check reports it' )
	    or diag join "\n", @problems;
};

subtest 'a reference that names its own directory' => sub {
	my $root = project();

	# './' names the directory of the page, and a directory is no
	# page. An empty answer reads as false in the walk of the
	# reachability check, which stops the walk at that page.
	#
	# A page that the walk marks on the way in still counts as
	# seen. The fixture therefore needs a second step: the home
	# page links one page, and that page links another.
	spew( "$root/web/one.body.html",
		qq{<h1>One</h1>\n<p><a href="two.html">Two</a></p>\n} );
	spew( "$root/web/two.body.html", "<h1>Two</h1>\n" );
	spew( "$root/web/index.body.html", <<'BODY' );
<h1>Home</h1>
<p><a href="./">Here</a></p>
<p><a href="one.html">One</a></p>
BODY

	my $rc = slurp("$root/.fuguwebrc");
	$rc =~ s{^keys "keys"}{page "one.html" {\n\ttitle = One\n\tbody  = one.body.html\n}\n\npage "two.html" {\n\ttitle = Two\n\tbody  = two.body.html\n}\n\nkeys "keys"}m
	    or die 'the fixture adds no page';
	spew( "$root/.fuguwebrc", $rc );

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;
	ok( !( grep { m{two\.html: no page links to it} } @problems ),
		'the walk reaches a page that a second page links' )
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
			mandoc  => $TRUE,
			lowdown => $TRUE,
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

	# WEB-KEYS-11. A binding goes in byte for byte beside its key.
	# A consumer verifies the target against these bytes, so a
	# build that rewrote one would publish a binding that fails.
	is(
		slurp("$out/keys/fugubsd-1-root.pub.fugubsd-1-release.sig"),
		$BINDING,
		'a binding file is copied byte for byte'
	);

	SKIP: {
		skip 'gpg(1) is not installed', 1 unless $GPG;

		is(
			scalar App::FuguWeb::Check->new(
				config => $config,
				out    => $out
			)->run,
			0,
			'and the built site passes its checks'
		);
	}

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

key "fugubsd-1-root" {
	status = current
}

key "fugubsd-1-release" {
	status = current
}
RC
	# The binding of that key goes with it: a binding whose signer
	# the description dropped names a key that no block holds.
	unlink "$root/web/keys/fugubsd-1-contact.asc";
	unlink "$root/web/keys/fugubsd-1-root.pub.fugubsd-1-contact.asc";
	spew(
		"$root/web/keys/SHA256",
		manifest(
			'fugubsd-1-root.pub'    => $ROOT,
			'fugubsd-1-release.pub' => $SIGNIFY,
			'fugubsd-1-root.pub.fugubsd-1-release.sig' => $BINDING,
		) );

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

	SKIP: {
		skip 'gpg(1) is not installed', 1 unless $GPG;

		my @problems =
		    App::FuguWeb::Check->new( config => $config, out => $out )
		    ->run;
		is_deeply( [@problems],
			['keys/stray.txt: in the output but not in the site'],
			'the check names a stray file below the root by its path'
		);
	}
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

key "fugubsd-1-root" {
	status = current
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
	SKIP: {
		skip 'gpg(1) is not installed', 1 unless $GPG;

		is(
			scalar App::FuguWeb::Check->new(
				config => $config,
				out    => $out
			)->run,
			0,
			'and the site passes its checks'
		);
	}

	my @generated =
	    App::FuguWeb::Check->new( config => $config, out => $out )
	    ->generated_pages;
	is_deeply( \@generated, ['keys/index.html'],
		'the checks hold the generated page' );
};

subtest 'the generated page carries no footer' => sub {
	my $root = project();

	# The footer is the prose of the project, and the chrome
	# copies it in unchanged. A relative link of it would resolve
	# against the directory of the page that carries it. The same
	# href therefore names one file from the root, and another
	# from keys/.
	spew( "$root/web/about.body.html", "<h1>About</h1>\n" );
	spew( "$root/web/footer.body.html",
		qq{<p><a href="about.html">About</a></p>\n} );

	my $rc = slurp("$root/.fuguwebrc");
	$rc =~ s{^keys "keys"}{page "about.html" {\n\ttitle    = About\n\tbody     = about.body.html\n\tunlinked = yes\n}\n\nkeys "keys"}m
	    or die 'the fixture adds no page';
	spew( "$root/.fuguwebrc", $rc );

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	like( slurp("$out/index.html"), qr{<footer>},
		'a page of the root carries the footer' );
	unlike( slurp("$out/keys/index.html"), qr{<footer>},
		'and a page below it does not' );

	SKIP: {
		skip 'gpg(1) is not installed', 1 unless $GPG;

		is(
			scalar App::FuguWeb::Check->new(
				config => $config,
				out    => $out
			)->run,
			0,
			'so the site passes its checks'
		);
	}
};

subtest 'the checks read the links of the generated page' => sub {
	my $root = project();

	# A navigation entry that names no page is wrong on every page
	# that carries the chrome. The generated page carries it too,
	# so the check must report it there under its own path.
	my $rc = slurp("$root/.fuguwebrc");
	$rc =~ s{^nav "index\.html" \{\n\tlabel = Home\n\}}{$&\n\nnav "missing.html" {\n\tlabel = Missing\n}}m
	    or die 'the fixture adds no navigation entry';
	spew( "$root/.fuguwebrc", $rc );

	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;

	ok( ( grep { $_ eq 'index.html: missing.html leads nowhere' }
			@problems ),
		'the check reports the page of the root' )
	    or diag join "\n", @problems;

	# The step back is part of the href that the generated page
	# carries, so the report names it.
	ok(
		(
			grep {
				$_ eq
				    'keys/index.html: ../missing.html leads'
				    . ' nowhere'
			} @problems
		),
		'and the generated page under its own path'
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
	my $pgp     = Fugu::OpenPGP->new;
	my $current = $pgp->decode_armor($OPENPGP_TWO);
	my $retired = $pgp->decode_armor($OPENPGP);

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

	# The clean refuses this directory, so the build must keep it.
	# WEB-OUTPUT-6 holds for a directory as it holds for a file.
	ok( site( $config, $out )->build, 'a second build succeeds' );
	ok( -d "$out/archive", 'and the build keeps it' );
	ok( !site( $config, $out )->clean, 'the clean refuses it too' );

	spew( "$out/archive/notes.txt", "mine\n" );
	ok( site( $config, $out )->build, 'a third build succeeds' );
	ok( -e "$out/archive/notes.txt", 'and it keeps a directory of files' );
};

subtest 'the build reports a stray directory' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	spew( "$out/archive/notes.txt", "mine\n" );

	# The build keeps a directory that no build made, and it says
	# so. An empty one gets the same report, because the build
	# keeps that one too.
	my $said = '';
	open my $saved, '>&', \*STDERR or die "Cannot save stderr: $!";
	close STDERR;
	open STDERR, '>', \$said or die 'Cannot capture stderr';

	my $again = App::FuguWeb::Site->new(
		config => $config,
		out    => $out,
		render => App::FuguWeb::Render->new(
			config  => $config,
			mandoc  => $TRUE,
			lowdown => $TRUE,
		),
	)->build;

	close STDERR;
	open STDERR, '>&', $saved or die "Cannot restore stderr: $!";

	ok( $again, 'a second build succeeds' );
	ok( -e "$out/archive/notes.txt", 'and it keeps the file' );
	like( $said, qr{archive/notes\.txt is in the output},
		'and it reports the file' );

	# An empty directory below the key directory is nobody's
	# build, so it stays. The report of it has its own subtest.
	mkdir "$out/keys/stale" or die "Cannot make the directory: $!";
	ok( site( $config, $out )->build, 'a third build succeeds' );
	ok( -d "$out/keys/stale", 'and it keeps an empty one' );
	ok( !site( $config, $out )->clean, 'the clean refuses it too' );
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

# renderers():
#	Whether every renderer of a page is installed. A subtest that
#	drives the real command needs them, and the rest of this file
#	needs none.
sub renderers ()
{
	for my $tool (qw(mandoc lowdown pod2man)) {
		return 0 unless system("command -v $tool >/dev/null 2>&1") == 0;
	}

	return 1;
}

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

subtest 'clean refuses a file that the site does not name' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	# The site names the key directory, so a walk that read a
	# prefix would take every name below it. The rule is the
	# shape, and no key file is named notes.txt.
	spew( "$out/keys/notes.txt", "mine\n" );

	ok( !site( $config, $out )->clean, 'the clean refuses' );
	ok( -e "$out/keys/notes.txt", 'and removes nothing' );
};

subtest 'the top level takes any plain file that a build could write' =>
    sub {
	# A renamed page leaves its old file behind, and the
	# description no longer names it. The clean must still take
	# it, or a rename would strand the output for good.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	spew( "$out/old-name.html", "a page of an earlier run\n" );

	ok( site( $config, $out )->clean, 'the clean takes the output' );
	ok( !-e $out, 'and the whole tree is gone' );
};

subtest 'clean refuses an empty directory that no build made' => sub {
	# A directory holds a name of the site, or is a directory of
	# the key tree. Anything else is somebody else's, and an empty
	# one carries no file that the walk could refuse instead.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	make_path("$out/photos");
	ok( !site( $config, $out )->clean, 'the clean refuses' );
	ok( -d "$out/photos", 'and removes nothing' );

	# The key tree is the one exception: its directories stay
	# after a description drops a key, and the clean takes them.
	remove_tree("$out/photos");
	ok( site( $config, $out )->clean, 'without it the clean succeeds' );
};

subtest 'a description with no keys block owns no well-known path' => sub {
	# A site of another maker holds security.txt too, so a
	# predicate that answered on the name alone would let the
	# clean delete that site.
	my $root = keyless();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;
	is( $config->keys_dir, undef, 'and it names no key directory' );

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	spew( "$out/.well-known/security.txt",       "Contact: mine\n" );
	spew( "$out/.well-known/openpgpkey/policy",  "" );
	spew( "$out/.well-known/openpgpkey/hu/ybndrfg8ejkmcpqxot1uwisza345h769",
		"mine\n" );

	my $hash = '.well-known/openpgpkey/hu/'
	    . 'ybndrfg8ejkmcpqxot1uwisza345h769';

	ok( site( $config, $out )->build, 'a second build succeeds' );
	ok( -e "$out/.well-known/security.txt",      'it keeps security.txt' );
	ok( -e "$out/.well-known/openpgpkey/policy", 'and the policy' );
	ok( -e "$out/$hash",                         'and the key of a hash' );

	ok( !site( $config, $out )->clean, 'the clean refuses the tree' );
	ok( -e "$out/.well-known/security.txt", 'and removes nothing' );
	ok( -e "$out/$hash",                    'the key of a hash as well' );
};

subtest 'a keyless description takes no foreign well-known tree' => sub {
	# The clean of a foreign target reads the description that it
	# can load. A .well-known directory alone must not make a tree
	# read like a built site.
	my ( $config, $reason ) = load( keyless() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	make_path("$out/.well-known");
	spew( "$out/index.html", "<h1>Someone else</h1>\n" );
	spew( "$out/style.css",  "body{}\n" );
	spew( "$out/.well-known/security.txt", "Contact: theirs\n" );

	ok( !site( $config, $out )->clean, 'the clean refuses' );
	ok( -e "$out/.well-known/security.txt", 'and removes nothing' );
};

subtest 'a keyless description owns no well-known directory' => sub {
	# The directory half of the rule. An empty tree carries no
	# file, so the file guard never reaches it.
	my ( $config, $reason ) = load( keyless() );
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = tempdir( CLEANUP => 1 ) . '/out';
	make_path("$out/.well-known/openpgpkey/hu");
	spew( "$out/index.html", "<h1>Someone else</h1>\n" );

	ok( !site( $config, $out )->clean, 'the clean refuses the tree' );
	ok( -d "$out/.well-known/openpgpkey/hu", 'and removes nothing' );
};

subtest 'the build names the stray directory that it keeps' => sub {
	# WEB-OUTPUT-4: the build keeps an entry that it may not
	# write, and it reports it. A silent build would leave the
	# operator to find the tree by hand.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	make_path("$out/photos/2024/raw");

	my $said = '';
	open my $saved, '>&', \*STDERR or die "Cannot save stderr: $!";
	close STDERR;
	open STDERR, '>', \$said or die 'Cannot capture stderr';

	my $again = App::FuguWeb::Site->new(
		config => $config,
		out    => $out,
		render => App::FuguWeb::Render->new(
			config  => $config,
			mandoc  => $TRUE,
			lowdown => $TRUE,
		),
	)->build;

	close STDERR;
	open STDERR, '>&', $saved or die "Cannot restore stderr: $!";

	ok( $again, 'a second build succeeds' );
	ok( -d "$out/photos/2024/raw", 'and it keeps the tree' );
	like( $said, qr{photos/2024/raw is in the output},
		'and it names the tree' );
};

subtest 'the clean refuses a directory of the source' => sub {
	# The build renders, so the skip comes before the first
	# assertion. A plan that arrives after one is not a plan.
	plan skip_all => 'a renderer is not installed' unless renderers();

	# The key files are the trust anchor of every release, and
	# each one sits at the top level of the key directory, where
	# the clean takes a plain file.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	for my $target (qw(web web/keys web/keys/deep)) {
		my ( $exit, $err ) = cli( $root, 'clean', '--out', $target );
		isnt( $exit, 0, "the clean refuses $target" );
		like( $err, qr{is the (?:source|key) directory},
			"and the target guard is the reason for $target" );
	}

	ok( -e "$root/web/keys/fugubsd-1-release.pub", 'the key survives' );
	ok( -e "$root/web/keys/SHA256",       'the manifest survives' );
	ok( -e "$root/web/keys/SHA256.sig",   'the signature survives' );
	ok( -e "$root/web/index.body.html",   'the source survives' );

	# The output directory that the description names is the one
	# exception below the source. This description names out, so
	# web/build is a directory of the source like any other.
	my ($exit) = cli( $root, 'build', '--out', 'web/build' );
	isnt( $exit, 0, 'the build refuses another directory of the source' );

	($exit) = cli( $root, 'build' );
	is( $exit, 0, 'and it takes the output that the site names' );

	# Every directory of the source, and not the key directory
	# alone. An operator directory there is content of the project.
	make_path("$root/web/img");
	spew( "$root/web/img/logo.svg", "logo\n" );

	for my $command (qw(build clean)) {
		my ($code) = cli( $root, $command, '--out', 'web/img' );
		isnt( $code, 0, "the $command refuses web/img" );
	}
	ok( -e "$root/web/img/logo.svg", 'the operator file survives' );
};

subtest 'a source that holds its own stylesheet' => sub {
	# The stylesheet guard alone would take this target, because
	# every build writes style.css and this source holds one. The
	# target guard is the rule that refuses it.
	my $root = project();
	spew( "$root/web/style.css", "body{}\n" );
	spew( "$root/.fuguwebrc", "site = Example\nnav \"index.html\" {\n" );

	my ( $config, $reason ) = load($root);
	ok( !$config, 'the description does not load' );

	my ($exit) = cli( $root, 'clean', '--out', 'web' );
	isnt( $exit, 0, 'the clean refuses the source directory' );
	ok( -e "$root/web/index.body.html", 'the source survives' );
	ok( -e "$root/web/keys/fugubsd-1-release.pub", 'the key survives' );

	# A source of plain files and no directory. Every other guard
	# takes this one, so the target guard is the only rule left.
	my $flat = project();
	spew( "$flat/.fuguwebrc", "site = Example\nnav \"index.html\" {\n" );
	spew( "$flat/web/style.css", "body{}\n" );
	remove_tree("$flat/web/keys");

	($exit) = cli( $flat, 'clean', '--out', 'web' );
	isnt( $exit, 0, 'and a flat source with a stylesheet as well' );
	ok( -e "$flat/web/index.body.html", 'that source survives too' );
};

subtest 'the clean refuses a foreign target with no stylesheet' => sub {
	# Outside the project the target guard says nothing, so the
	# stylesheet is the whole rule. Every build writes it.
	my $root = project();
	spew( "$root/.fuguwebrc", "site = Example\nnav \"index.html\" {\n" );

	my $victim = tempdir( CLEANUP => 1 ) . '/victim';
	spew( "$victim/notes.txt",  "mine\n" );
	spew( "$victim/README.txt", "mine\n" );

	my ($exit) = cli( $root, 'clean', '--out', $victim );
	isnt( $exit, 0, 'the clean refuses it' );
	ok( -e "$victim/notes.txt", 'and removes nothing' );

	# The same target with a stylesheet is the output of a build.
	spew( "$victim/style.css", "body{}\n" );
	($exit) = cli( $root, 'clean', '--out', $victim );
	is( $exit, 0, 'and it takes one that holds the stylesheet' );
	ok( !-e $victim, 'which is gone' );
};

# break($root):
#	Break the description of a project, as a description usually
#	breaks: a fault in the last block that somebody edited.
#	Fugu::Config keeps every setting and block that it read before
#	the fault, so the names above it survive.
sub break ($root)
{
	open my $fh, '>>', "$root/.fuguwebrc"
	    or die "Cannot append to the description: $!";
	print {$fh} "\nnav \"stray.html\" {\n";
	close $fh;

	my ( $config, $reason ) = load($root);
	ok( !$config, 'the description does not load' );

	return;
}

subtest 'a broken description guards its own directories' => sub {
	# The clean is the command an operator reaches for when a
	# description is broken, so this path is the real one. The
	# guard must still answer for the directories of that project.
	my $root = project();
	break($root);

	for my $target (qw(web/keys web)) {
		my ( $exit, $err ) = cli( $root, 'clean', '--out', $target );
		isnt( $exit, 0, "the clean refuses $target" );
		like( $err, qr{is the source directory},
			"and the target guard is the reason for $target" );
	}

	ok( -e "$root/web/keys/fugubsd-1-release.pub", 'the key survives' );
	ok( -e "$root/web/keys/SHA256",     'the manifest survives' );
	ok( -e "$root/web/keys/SHA256.sig", 'the signature survives' );
	ok( -e "$root/web/index.body.html", 'the source survives' );
};

subtest 'a broken description reads its own directory names' => sub {
	# A project of no default name at all. A guard that read a
	# default instead would refuse the wrong directory, and it
	# would miss the source key directory of this one.
	my $root = tempdir( CLEANUP => 1 );
	spew( "$root/site/index.body.html", "<h1>H</h1>\n" );
	spew( "$root/site/pubkeys/fugubsd-1-release.pub", $SIGNIFY );
	spew( "$root/site/pubkeys/SHA256",
		manifest( 'fugubsd-1-release.pub' => $SIGNIFY ) );
	spew( "$root/site/pubkeys/SHA256.sig", $SIGNATURE );
	spew( "$root/.fuguwebrc", <<'RC' );
site       = Example
source_dir = site
out_dir    = site/build

nav "index.html" {
	label = Home
}

page "index.html" {
	title = Home
	body  = index.body.html
}

keys "pubkeys" {
	org = fugubsd
}

key "fugubsd-1-release" {
	status = current
}
RC

	# The output that this description names sits inside the
	# source, as the default layout does. The build runs first,
	# because a broken description renders nothing.
	my $built = 0;
	SKIP: {
		skip 'a renderer is not installed', 2 unless renderers();

		my ($code) = cli( $root, 'build' );
		is( $code, 0, 'the build succeeds into site/build' );
		ok( -d "$root/site/build/pubkeys",
			'and it writes the key directory' );
		$built = 1;
	}

	break($root);

	# The source of this project, and the key directory in it.
	for my $target (qw(site site/pubkeys)) {
		my ( $exit, $err ) = cli( $root, 'clean', '--out', $target );
		isnt( $exit, 0, "the clean refuses $target" );
		like( $err, qr{is the source directory},
			"and the target guard is the reason for $target" );
	}
	ok( -e "$root/site/pubkeys/fugubsd-1-release.pub", 'the key survives' );
	ok( -e "$root/site/index.body.html",               'the source too' );

	# A guard that read a default output directory would refuse
	# this one, and a guard that read a default key directory
	# name would refuse the tree inside it.
	SKIP: {
		skip 'a renderer is not installed', 2 unless $built;

		my ($took) = cli( $root, 'clean', '--out', 'site/build' );
		is( $took, 0, 'the clean takes that output' );
		ok( !-e "$root/site/build", 'which is gone' );
	}

	# A directory of no build at all. The target guard says
	# nothing about it, so the stylesheet rule answers.
	spew( "$root/web/build/notes.txt", "mine\n" );

	my ( $exit, $err ) = cli( $root, 'clean', '--out', 'web/build' );
	isnt( $exit, 0, 'the clean refuses a directory of no build' );
	like( $err, qr{holds no style\.css},
		'and the stylesheet is the reason' );
	ok( -e "$root/web/build/notes.txt", 'and removes nothing' );
};

subtest 'a broken description cleans its own output' => sub {
	# The build renders, so the skip comes before the first
	# assertion. A plan that arrives after one is not a plan.
	plan skip_all => 'a renderer is not installed' unless renderers();

	# A clean of a directory that is not there returns success
	# without a walk, so the build has to run first.
	my $root = project();
	my ($code) = cli( $root, 'build' );
	is( $code, 0, 'a build of a whole description succeeds' );
	ok( -d "$root/out/keys", 'and it writes the key directory' );

	break($root);

	my ($exit) = cli( $root, 'clean', '--out', 'out' );
	is( $exit, 0, 'the clean takes the output of a build' );
	ok( !-e "$root/out", 'which is gone' );
};

subtest 'a broken description keeps the org of its keys block' => sub {
	# The org pins a key file to this organization. A description
	# that did not load names it all the same, so the published
	# key of another organization stays refused.
	my $root = project();
	break($root);

	my $victim = tempdir( CLEANUP => 1 ) . '/victim';
	spew( "$victim/style.css",  "body{}\n" );
	spew( "$victim/index.html", "<h1>Theirs</h1>\n" );
	spew( "$victim/keys/otherorg-1-release.pub", $SIGNIFY );

	my ($exit) = cli( $root, 'clean', '--out', $victim );
	isnt( $exit, 0, 'the clean refuses it' );
	ok( -e "$victim/keys/otherorg-1-release.pub",
		'and the key of another org survives' );
};

subtest 'a broken description of the default layout' => sub {
	# The build renders, so the skip comes before the first
	# assertion. A plan that arrives after one is not a plan.
	plan skip_all => 'a renderer is not installed' unless renderers();

	# A description that names neither directory takes the two
	# defaults, and the anonymous config must read them from the
	# file and not invent them.
	my $root = project( rc => $KEYS_BLOCK, files => {} );
	spew( "$root/.fuguwebrc", <<"RC" );
site = Example

nav "index.html" {
	label = Home
}

page "index.html" {
	title = Home
	body  = index.body.html
}

$KEYS_BLOCK
RC

	my ($code) = cli( $root, 'build' );
	is( $code, 0, 'the build succeeds into web/build' ) or diag "exit=$code";
	ok( -d "$root/web/build/keys", 'and it writes the key directory' );

	break($root);

	my ($exit) = cli( $root, 'clean', '--out', 'web/build' );
	is( $exit, 0, 'the clean takes the default output directory' );
	ok( !-e "$root/web/build",          'which is gone' );
	ok( -e "$root/web/index.body.html", 'and the source survives' );
};

subtest 'a key name of another organization' => sub {
	# The org comes from the description, and never from a name.
	# A guard that read a fixed org would take the key of this
	# site and refuse the key of any other one.
	my $root = project(
		rc => <<'RC'
keys "keys" {
	org = acme
}

key "acme-1-release" {
	status = current
}
RC
		,
		keys => { 'acme-1-release.pub' => $SIGNIFY },
	);

	my ( $config, $reason ) = load($root);
	ok( $config, 'a description of another org loads' ) or diag $reason;
	is( $config->keys_org, 'acme', 'and it names that org' );

	ok( App::FuguWeb::Keys->shaped( $config, 'keys/acme-1-release.pub' ),
		'the key of this site is shaped' );
	ok( !App::FuguWeb::Keys->shaped( $config, 'keys/fugubsd-1-release.pub' ),
		'and the key of another org is not' );

	# The same holds when the description does not load.
	break($root);
	my ($anon) = ( App::FuguWeb::Config->anonymous($root) );
	is( $anon->keys_org, 'acme', 'a broken description keeps the org' );
	ok( App::FuguWeb::Keys->shaped( $anon, 'keys/acme-1-release.pub' ),
		'and the key of this site stays shaped' );
	ok( !App::FuguWeb::Keys->shaped( $anon, 'keys/fugubsd-1-release.pub' ),
		'and the key of another org stays refused' );
};

subtest 'a keyless description keeps its guard when it breaks' => sub {
	# A description that names no keys block owns no key shape,
	# and a break must not give it one. Another maker's site holds
	# security.txt and a key directory too.
	my $root = keyless();
	break($root);

	my $victim = tempdir( CLEANUP => 1 ) . '/victim';
	spew( "$victim/style.css",  "body{}\n" );
	spew( "$victim/index.html", "<h1>Theirs</h1>\n" );
	spew( "$victim/.well-known/security.txt", "Contact: theirs\n" );
	spew( "$victim/keys/fugubsd-1-release.pub", $SIGNIFY );

	my ($exit) = cli( $root, 'clean', '--out', $victim );
	isnt( $exit, 0, 'the clean refuses it' );
	ok( -e "$victim/.well-known/security.txt", 'and security.txt survives' );
	ok( -e "$victim/keys/fugubsd-1-release.pub", 'and the key with it' );
};

subtest 'the build refuses a staging tree that no build made' => sub {
	# A build writes one flat directory of plain files into the
	# staging directory. The clean refuses anything else there,
	# so WEB-OUTPUT-6 says the build must keep it.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	my $staging = "$out/" . App::FuguWeb::STAGING_DIR();
	make_path("$staging/sub");
	spew( "$staging/sub/mine.txt", "mine\n" );

	ok( !site( $config, $out )->clean, 'the clean refuses the tree' );
	ok( !site( $config, $out )->build, 'and a second build refuses it' );
	ok( -e "$staging/sub/mine.txt",    'and removes nothing' );
};

subtest 'the prune and the clean answer alike' => sub {
	# WEB-OUTPUT-6: a build must never remove a file that the
	# clean refuses. The two read one predicate, and this test
	# plants a name and compares the two answers for it.
	#
	# A name that the site holds gets skipped below: the build
	# rewrites it, so no prune ever sees it.
	my @name = (
		'keys/notes.txt',
		'keys/archive/f.txt',
		'keys/README',
		'keys/.hidden',
		'keys/fugubsd-9-release.pub',
		'keys/fugubsd-9-signing.asc',
		'keys/KEYS',
		'.well-known/security.txt',
		'.well-known/openpgpkey/policy',
		'.well-known/notes.txt',
		'.well-known/openpgpkey/hu/ybndrfg8ejkmcpqxot1uwisza345h769',
		'.well-known/openpgpkey/hu/short',
		'.well-known/openpgpkey/hu/deep/f',
		'sub/page.html',
		'stale.html',
		App::FuguWeb::STAGING_DIR() . '/mine/notes.txt',
	);

	# A directory answers the same rule, and an empty one is the
	# case that no planted file reaches: the walk gives it as a
	# leaf of its own.
	my @dir = (
		'photos',
		'photos/2024/raw',
		'keys/stale',
		'.well-known/acme-challenge',
		App::FuguWeb::STAGING_DIR() . '/mine',
	);

	# The clean reads the description that it can load, so a
	# project with no keys block must answer alike as well.
	my $tested = 0;
	for my $maker ( \&project, \&keyless ) {
		for my $name ( @name, @dir ) {
			my $is_dir = grep { $_ eq $name } @dir;

			my $root = $maker->();
			my ( $config, $reason ) = load($root);
			ok( $config, "$name: the description loads" ) or next;

			next if grep { $_ eq $name } $config->inventory;
			$tested++;

			my $out = "$root/out";
			ok( site( $config, $out )->build,
				"$name: the build succeeds" );

			$is_dir
			    ? make_path("$out/$name")
			    : spew( "$out/$name", "planted\n" );
			my $takes = site( $config, $out )->clean ? 1 : 0;

			# The clean of a taken target removed the
			# output, so the second run builds and plants
			# again.
			my $again = $maker->();
			my ($second) = load($again);
			my $out2 = "$again/out";
			site( $second, $out2 )->build;
			$is_dir
			    ? make_path("$out2/$name")
			    : spew( "$out2/$name", "planted\n" );
			site( $second, $out2 )->build;
			my $removes = -e "$out2/$name" ? 0 : 1;

			is( $removes, $takes,
				"$name: the prune and the clean answer alike"
			);
		}
	}

	# The test compares two answers, so it passes when both refuse.
	# It cannot catch a refusal that is too wide on its own: the
	# subtests above hold each side to the answer that it owes.
	#
	# A filter that dropped a name would prove less than it says,
	# so the count is the one that the loop reaches today.
	is( $tested, 39, 'the test reached every name of both makers' );
};

# WEB-OUTPUT-10. A binding file takes a shape of the key directory, so
# the build removes a stale one and the clean takes the tree that holds
# it. The inventory names what the site holds today, so it cannot
# answer for a binding that a promote dropped.
subtest 'a stale binding takes the shape of the key directory' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	my $stale = 'keys/fugubsd-1-release.pub.fugubsd-1-root.sig';
	my $other = 'keys/fugubsd-1-release.pub.fugubsd-1-root.jpg';
	spew( "$out/$stale", "stale\n" );
	spew( "$out/$other", "mine\n" );

	# WEB-OUTPUT-10. A key file of each type takes a shape of the
	# key directory, and the description of this site names no
	# certificate at all.
	my $dropped = 'keys/fugubsd-9-sign.pem';
	spew( "$out/$dropped", "stale\n" );

	ok( site( $config, $out )->build, 'a second build succeeds' );
	ok( !-e "$out/$stale",   'the build removes the stale binding' );
	ok( !-e "$out/$dropped", 'and the stale certificate with it' );
	ok( -e "$out/$other",    'and keeps the name of another shape' );

	ok( !site( $config, $out )->clean, 'the clean refuses the tree' );
	ok( -e "$out/$other", 'and removes nothing' );
};

subtest 'the shape of a Web Key Directory name' => sub {
	# A stale hu name is the encoded SHA-1 of a local part, so it
	# holds 32 characters of the z-base-32 alphabet. The build
	# removes one of that shape and keeps every other name, and
	# the clean answers the same way.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	my $hu    = '.well-known/openpgpkey/hu';
	my $stale = "$hu/ybndrfg8ejkmcpqxot1uwisza345h769";
	my $other = "$hu/holiday.jpg";

	spew( "$out/$stale", "stale\n" );
	spew( "$out/$other", "mine\n" );

	ok( site( $config, $out )->build, 'a second build succeeds' );
	ok( !-e "$out/$stale", 'the build removes the stale hash' );
	ok( -e "$out/$other",  'and keeps the name of another shape' );

	ok( !site( $config, $out )->clean, 'the clean refuses the tree' );
	ok( -e "$out/$other", 'and removes nothing' );
};

subtest 'a signify key file that holds no signify key' => sub {
	# The extension gives the type, so a name that ends in .pub is
	# a signify key by its name alone. The guards of Fugu::KeyDir
	# hold an OpenPGP key and skip every other type, so a file of
	# any content would publish under that name.
	# The delimiter is built and never written, because the secret
	# gate reads this file and a block of that name is what it
	# looks for. The bytes below hold no key of any kind.
	my $block   = join ' ', 'PGP', 'PRIVATE', 'KEY', 'BLOCK';
	my $private = "-----BEGIN $block-----\n\n"
	    . "bm90IGEga2V5IG9mIGFueSBraW5k\n"
	    . "=AAAA\n"
	    . "-----END $block-----\n";

	my $root = project(
		keys => { 'fugubsd-1-release.pub' => $private },
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

	my $keys = App::FuguWeb::Keys->new( config => $config );
	ok( !$keys->generated, 'the key directory refuses to generate' );
	like( $keys->error, qr{a signify public key holds 2},
		'and the reason names the shape' );

	my $out = "$root/out";
	ok( !site( $config, $out )->build, 'the build fails' );
	ok( !-e "$out/keys/fugubsd-1-release.pub",
		'and it publishes no private key' );

	my @problems =
	    App::FuguWeb::Check->new( config => $config, out => $out )->run;
	ok( ( grep { m{signify public key holds 2} } @problems ),
		'and the check reports it' )
	    or diag join "\n", @problems;
};

subtest 'a signify key body that is not a key' => sub {
	my %case = (
		'a body of the wrong length' =>
		    "untrusted comment: x\nRWRPa1Nd3YmPwqMM\n",
		'a body that names no algorithm' =>
		    "untrusted comment: x\n"
		    . ( 'A' x 56 ) . "\n",
		'no untrusted comment line' =>
		    "a comment\nRWRPa1Nd3YmPwqMMjxtMv+TPkCbHp43jYR8s7TGqxx1EI70I2bKmsAlE\n",
	);

	for my $name ( sort keys %case ) {
		my $root = project(
			keys => { 'fugubsd-1-release.pub' => $case{$name} },
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
		ok( $config, "$name loads" ) or diag $reason;

		my $keys = App::FuguWeb::Keys->new( config => $config );
		ok( !$keys->generated, "and $name is refused" );
	}
};

subtest 'a signature that is not a signify signature' => sub {
	# The build copies the signature and verifies nothing: a site
	# that verified its own manifest would prove nothing. It reads
	# the shape, because a file of another shape fails at every
	# consumer install and never here.
	my %case = (
		'the wrong line count' => [
			"untrusted comment: x\n",
			qr{a signify signature holds 2},
		],
		'no untrusted comment line' => [
			"a comment\n" . ( 'A' x 99 ) . "=\n",
			qr{no untrusted comment line},
		],
		'a body of the wrong length' => [
			"untrusted comment: x\nRWS/n+2mbBbQ\n",
			qr{not 100 base64 characters},
		],
		'a body that names no algorithm' => [
			"untrusted comment: x\n" . ( 'A' x 99 ) . "=\n",
			qr{names no signify algorithm},
		],
	);

	for my $name ( sort keys %case ) {
		my ( $bytes, $why ) = @{ $case{$name} };

		my $root =
		    project( files => { 'web/keys/SHA256.sig' => $bytes } );
		my ( $config, $reason ) = load($root);
		ok( $config, "$name loads" ) or diag $reason;

		my @problems =
		    App::FuguWeb::Keys->new( config => $config )->problems;
		ok( ( grep { $_ =~ $why } @problems ),
			"and the check reports $name" )
		    or diag join "\n", @problems;
	}
};

subtest 'a signature that the checkout does not hold' => sub {
	# The description refuses a directory with no manifest pair,
	# so an unreadable signature reaches the check through a
	# directory that lost it after the load.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	unlink "$root/web/keys/SHA256.sig" or die "Cannot remove: $!";

	my @problems =
	    App::FuguWeb::Keys->new( config => $config )->problems;
	ok( ( grep { m{SHA256\.sig: cannot read it} } @problems ),
		'the check reports the missing signature' )
	    or diag join "\n", @problems;
};

subtest 'clean refuses a symlink that no build made' => sub {
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

	# A symlink below the root. The clean deletes a tree without
	# asking, so it must refuse anything that a build cannot have
	# written.
	symlink '/etc/passwd', "$out/keys/link" or die "Cannot link: $!";

	ok( !site( $config, $out )->clean, 'the clean refuses' );
	ok( -e "$out/keys/fugubsd-1-release.pub", 'and removes nothing' );
};

subtest 'clean refuses a foreign staging tree' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	# The build writes one flat directory of sources into the
	# staging directory. A tree below it belongs to whoever made
	# it, and the name must not carry the whole target with it.
	my $victim = tempdir( CLEANUP => 1 ) . '/victim';
	spew( "$victim/.man/deep/keep.txt", "important\n" );

	ok( !site( $config, $victim )->clean, 'the clean refuses' );
	ok( -e "$victim/.man/deep/keep.txt", 'and removes nothing' );
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

	# The site names each published key, so the clean removes the
	# key directory of a site that it read.
	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );
	ok( site( $config, $out )->clean, 'and the clean removes it' );
	ok( !-e $out, 'the whole tree is gone' );

	# A directory with no description at all names nothing, so
	# only one flat directory of files is a site. Without that
	# rule, a clean of a path that an operator typed would take
	# whatever the path holds.
	my $bare = tempdir( CLEANUP => 1 ) . '/build';
	spew( "$bare/somebody/precious.txt", "precious\n" );

	my $anonymous = App::FuguWeb::Config->anonymous( $root );
	ok( !site( $anonymous, $bare )->clean,
		'a clean with no description refuses a tree' );
	ok( -e "$bare/somebody/precious.txt", 'and removes nothing' );
};

subtest 'a description that drops its keys block' => sub {
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );
	ok( -d "$out/keys", 'the key directory is there' );

	# A site that drops the whole block strands the published
	# tree. The site names nothing under keys/ any more, so the
	# clean refuses it. A clean deletes without asking, and it
	# reads the site and never a guess.
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

	ok( !site( $bare, $out )->clean, 'the clean refuses the output' );
	ok( -e "$out/keys/fugubsd-1-release.pub", 'and removes nothing' );

	# The operator removes the directory, or names the block
	# again. Either one makes the site whole, and the clean then
	# reads a site that it can account for.
	remove_tree("$out/keys");
	remove_tree("$out/.well-known");
	ok( site( $bare, $out )->clean, 'the clean succeeds once it is gone' );
	ok( !-e $out, 'and the whole tree with it' );
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
	# The link points at a directory that is there, so the write
	# would succeed and _check_links is the only thing that stops
	# it. A dangling link would fail at the write instead, and
	# prove nothing about the guard.
	remove_tree("$out/.well-known");
	my $elsewhere = tempdir( CLEANUP => 1 );
	symlink $elsewhere, "$out/.well-known" or die "Cannot link: $!";

	ok( !site( $config, $out )->build, 'a build with a linked tree fails' );
	is_deeply( App::FuguWeb::list_tree($elsewhere), [],
		'and it writes no key through the link' );
	ok( -l "$out/.well-known", 'and it keeps the link' );
};

subtest 'the build refuses a symlink at the staging directory' => sub {
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

	# _prepare_output removes the staging path, so a link there
	# would go without a word and the operator would lose it.
	my $target = tempdir( CLEANUP => 1 );
	symlink $target, "$out/" . App::FuguWeb::STAGING_DIR()
	    or die "Cannot link: $!";

	ok( !site( $config, $out )->build, 'a second build refuses' );
	ok( -l "$out/" . App::FuguWeb::STAGING_DIR(), 'and it keeps the link' );
	ok( -d $target, 'and the target as well' );
};

subtest 'the build refuses a symlink below the staging directory' => sub {
	# The skip comes before the first assertion. A plan that
	# arrives after one turns a failed assertion into a pass.
	my $probe = tempdir( CLEANUP => 1 );
	plan skip_all => 'cannot make a symlink here'
	    unless symlink '/nonexistent', "$probe/link";

	# _check_links reads the staging path itself, and never a name
	# below it. _drop_staging is the guard of those, and a build
	# writes one flat directory of plain files there.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	my $staging = "$out/" . App::FuguWeb::STAGING_DIR();
	make_path($staging);
	my $target = tempdir( CLEANUP => 1 ) . '/theirs.1';
	spew( $target, "theirs\n" );
	symlink $target, "$staging/tool.1" or die "Cannot link: $!";

	ok( !site( $config, $out )->build, 'a second build refuses' );
	ok( -l "$staging/tool.1", 'and it keeps the link' );
	ok( -e $target,           'and the target as well' );

	ok( !site( $config, $out )->clean, 'the clean refuses it too' );
};

subtest 'the build refuses a symlink above a key path' => sub {
	# The skip comes before the first assertion. A plan that
	# arrives after one turns a failed assertion into a pass.
	my $probe = tempdir( CLEANUP => 1 );
	plan skip_all => 'cannot make a symlink here'
	    unless symlink '/nonexistent', "$probe/link";

	# A link at any directory of a written path sends the bytes
	# through it, not only a link at the first segment. The key
	# tree is three deep, so each level needs the rule.
	my $hu = '.well-known/openpgpkey';

	for my $where ( '.well-known', $hu, "$hu/hu" ) {
		my $root = project();
		my ($config) = load($root);
		my $out = "$root/out";
		ok( site( $config, $out )->build, "$where: the build succeeds" );

		remove_tree("$out/.well-known");
		make_path( "$out/" . ( $where =~ s{/[^/]+\z}{}r ) )
		    if $where =~ m{/};

		my $elsewhere = tempdir( CLEANUP => 1 );
		symlink $elsewhere, "$out/$where" or die "Cannot link: $!";

		ok( !site( $config, $out )->build, "$where: a build refuses" );
		is_deeply( App::FuguWeb::list_tree($elsewhere), [],
			"$where: and writes nothing through the link" );
	}
};

subtest 'the build keeps a symlink of the top level' => sub {
	# The skip comes before the first assertion. A plan that
	# arrives after one turns a failed assertion into a pass.
	my $probe = tempdir( CLEANUP => 1 );
	plan skip_all => 'cannot make a symlink here'
	    unless symlink '/nonexistent', "$probe/link";

	# The prune reads _build_made as well as _owns, and a name of
	# the top level passes _owns whatever it is. A link there is
	# never a thing that a build wrote, so the prune must keep it
	# and the clean must refuse it.
	my $root = project();
	my ( $config, $reason ) = load($root);
	ok( $config, 'the description loads' ) or diag $reason;

	my $out = "$root/out";
	ok( site( $config, $out )->build, 'the build succeeds' );

	my $target = tempdir( CLEANUP => 1 ) . '/elsewhere.html';
	spew( $target, "theirs\n" );
	symlink $target, "$out/stale.html" or die "Cannot link: $!";

	ok( site( $config, $out )->build, 'a second build succeeds' );
	ok( -l "$out/stale.html", 'and it keeps the link' );
	ok( -e $target,           'and the target as well' );

	ok( !site( $config, $out )->clean, 'the clean refuses the link' );
	ok( -l "$out/stale.html", 'and removes nothing' );
};

subtest 'the build keeps a symlink it never writes through' => sub {
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

	# The build writes the inventory and no more. A link on any
	# other path is somebody else's, and the build leaves it.
	my $target = tempdir( CLEANUP => 1 );
	symlink $target, "$out/photos" or die "Cannot link: $!";

	ok( site( $config, $out )->build, 'a second build succeeds' );
	ok( -l "$out/photos", 'and it keeps the link' );

	# The clean is the stricter of the two here, by design: it
	# deletes a tree without asking, and a link is never a thing
	# that a build wrote.
	ok( !site( $config, $out )->clean, 'the clean refuses the link' );
	ok( -l "$out/photos", 'and removes nothing' );
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
