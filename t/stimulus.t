use Test::More;

use Modern::Perl;
use autodie qw(:default); # Not applying to system()

my $script_name = "dumpio2curl.pl";
my $stim_dir = "t/stimulus";

sub check_stim {
	my ($name) = @_;

	die "Stimulus files for $name not found\n" unless -f "$stim_dir/$name.in" and -f "$stim_dir/$name.expected";
	my $cmd = "perl $script_name $stim_dir/$name.in | diff -q -s - $stim_dir/$name.expected > /dev/null 2>&1";
	system($cmd);

	die "Stimulus process for $name failed to execute: $!\n" if $? == -1;
	die "Stimulus process for $name died with signal ".($? & 127)."\n" if $? & 127;
	my $exit_status = $? >> 8;
	die "Stimulus process for $name gave unexpected exit status $exit_status\n" if $exit_status > 1;

	# $exit_status == 0 --> match, 1 --> no match
	return !$exit_status; # Match
}

my @stim_files = eval {
	my %possible_stimulus;
	opendir(my $dir, $stim_dir);
	while(readdir $dir) {
		my ($base) = /^(\w+)/;
		$possible_stimulus{$base} += 1  if /^\w+\.in$/;
		$possible_stimulus{$base} += 10 if /^\w+\.expected$/;
	}
	return grep { $possible_stimulus{$_} == 11} keys %possible_stimulus;
};

plan(tests => scalar @stim_files);

ok(check_stim($_), $_) foreach @stim_files;
