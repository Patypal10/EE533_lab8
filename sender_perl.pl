#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;

# Check arguments
if (@ARGV != 2) {
    print "Usage: perl sender.pl <input_file> <dest_ip>\n";
    exit 1;
}

my ($filename, $dest_ip) = @ARGV;
my $dest_port = 5005;

# Read 200 lines from file
open(my $fh, '<', $filename) or die "Cannot open file: $!";
my @lines;
while (my $line = <$fh>) {
    chomp $line;
    push @lines, $line;
    last if @lines == 200;
}
close($fh);

if (@lines < 200) {
    print "Error: file has only " . scalar(@lines) . " lines, need 200\n";
    exit 1;
}

# Convert hex values to bytes
my $data = '';
foreach my $line (@lines) {
    $data .= chr(hex($line));
}

# Send as single UDP packet
my $socket = IO::Socket::INET->new(
    PeerAddr => $dest_ip,
    PeerPort => $dest_port,
    Proto    => 'udp'
) or die "Cannot create socket: $!";

$socket->send($data) or die "Cannot send data: $!";
$socket->close();

print "Sent " . length($data) . " bytes to $dest_ip:$dest_port\n";
print "First 16 bytes: " . join(' ', map { sprintf('%02X', ord($_)) } split(//, substr($data, 0, 16))) . "\n";
print "Last  16 bytes: " . join(' ', map { sprintf('%02X', ord($_)) } split(//, substr($data, -16))) . "\n";
