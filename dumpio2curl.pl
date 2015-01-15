#!/usr/bin/perl

use strict;
use warnings;
use 5.010;
use bytes;

# Across line variables
my $last_direction = "";
my $in_buf = "";

sub req_to_curl {
	my ($block) = @_;
	my @lines = split(/\n/, $block);

	my $partial_url = ""; # Built piecewise

	# The first line should be the request
	while(local $_ = shift @lines) {
		if (my ($req, $path) = /^(\S+) \s+ (\S+) \s+ HTTP/x) {
			# Standard CURL header
			say "curl -v \\";
			say "--header \"User-agent:\" --header \"Accept:\" \\"; # Suppress default headers

			say "--request \"$req\" \\";
			$partial_url = $path; # Need host before outputting
			last;
		} else {
			warn("Expected request entry, line $.\n");
		}
	}

	# Next we should have the headers
	while(local $_ = shift @lines) {
		last if /^$/; # Empty line signifies the start of the data block

		if(my($host) = /^Host: \s* (.*)/xi) {
			# Handle the host entry seperately
			$partial_url = $host.$partial_url;
			next;
		}

		# Print header line
		s/"/\\"/g;
		say "--header \"$_\" \\";
	}

	# Next we may have some data
	while(local $_ = shift @lines) {
		# Print data line
		s/"/\\"/g;
		say "--data \"$_\" \\";
	}

	# Cap it off with the URL - TODO: HTTPS support would be nice
	say "http://$partial_url" if $partial_url;
}


while(<>) {
	#[Wed Jan 07 10:50:05.743358 2015] [dumpio:trace7] [pid 21414] mod_dumpio.c(103): [client ::1:33975] mod_dumpio:  dumpio_in (data-HEAP): X-Forwarded-Server: localhost:88\r\n
	my ($timestamp, $pid, $client, $direction, $data) = /^\[([^\]]*)\] \s+ \[dumpio:trace7\] \s+ \[pid \s+ (\d+)\].* \[client \s+ ::\d+:(\d+)\] \s+ mod_dumpio: \s+ dumpio_(\w+) \s+ \(data-HEAP\): \s+ (.*)$/x;

	next unless defined($timestamp);
	next if $data =~ /^(\d+)\sbytes$/; # Just length, not content

	# Content ends with "/r/n" - strip it off
	$data =~ s/\\r\\n$//;

	# Need to output curl command at end of input block
	if ($direction eq "out" && $last_direction ne "out") {
		# It is possible that we have a partial input block - missed the start
		# Easiest way to avoid this is to manually look for the HTTP header line
		if($in_buf =~ /\S+ \S+ HTTP/) {
			req_to_curl($in_buf);
		}
		$in_buf = "";
	}
	
	if ($direction ne $last_direction) {
		if ($last_direction) {
			# Not the first entry
			print "\n"; # Space between blocks
			print "\n" if $direction eq "in"; # Double space inputs
		}

		# Print header at start of block - ensures right metadata is used
		say "# $timestamp - pid $pid - client $client";
	}

	if ($direction eq "out") { # Server output
		foreach(split(/\\n/, $data)) {
			s/\\r$//;
			say "# $_";
		}
	} else { # Input to server
		# Much easier to collect and bulk parse rather than do it line by line
		$in_buf .= $data."\n";
	}

	$last_direction = $direction;
}

END {
	if($in_buf =~ /\S+ \S+ HTTP/) {
		req_to_curl($in_buf);
	}
}

=head1 NAME

dumpio2curl.pl - Extracts dumpio output from Apache logs for debugging and replaying.

=head1 USAGE

	./dumpio2curl.pl apache.log
	tail -n 200 apache.log | ./dumpio2curl.pl
	tail -n 200 apache.log | ./dumpio2curl.pl > replay.curl
	bash replay.curl

=head1 DESCRIPTION

This program parses output from the Apache module mod_dumpio present in Apache 2.4.
Prior versions of Apache use a slightly different and incompatible line format.

If you are using a prior version of Apache I suggest looking at
dumpio_parser.pl by Geoffrey Simmons, http://uplex.de/dumpio_parser

Apache can be configured to output all input and/or output data. When presented
in the log file the data is mixed in with other Apache logs as well as dump_io
providing a lot of information about filesystem interactions.

This program extracts just the data which was sent, ignoring all other log lines.

Input log data is presented as a curl command. This is an easy to read format and
allows trivial replaying of the request in a shell. The output can actually be
executed as a bash script if desired.

Output data is presented as the raw data transmitted, this is easy to understand
and allows quick comparison to curl output if desired.
# characters are prepended which allows the output to be used as a shell script.

This program is designed to be used in a development environment with a controlled
stimulus to be examined and repeated. It does not support multiple simultaneous
requests. It has also not been tested on large exposed server log files.

=head1 DEPENDENCIES

This script does not rely on any non-core Perl modules.

=head1 AUTHOR

David Tulloh <dumpio-david@tulloh.id.au>

=head1 LICENSE AND COPYRIGHT

Copyright 2015 David Tulloh

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
