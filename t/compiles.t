use Test::More tests => 4;

use Modern::Perl;
use IPC::Run3 qw/run3/;

my $script_name = "dumpio2curl.pl";

my ($stdout, $stderr);
my $cmd = [ 'perl', '-c', $script_name ];
eval { run3($cmd, \undef, \$stdout, \$stderr) };
my $error = $@;
my $exit_status = $?;

is ($error, "", "No execution error");
is ($exit_status, 0, "Good exit status");
is ($stdout, "", "No unexpected output");
is ($stderr, "$script_name syntax OK\n", "Good syntax");
