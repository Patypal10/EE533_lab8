#!/usr/bin/perl
use strict;
use warnings;

# ============================================================================
# Usage: ./read_fifo.pl <output_file> <num_lines>
# FIFO format: {ctrl[7:0], data[63:0]}
# Output per line: 0x<18 hex digits>
# ============================================================================

my $mem_addr_reg = "0x2000204";
my $dout_reg_lsb = "0x2000208";
my $dout_reg_msb = "0x200020C";
my $ctrl_out_reg = "0x2000210";

if (@ARGV != 2) {
    die "Usage: $0 <output_file> <num_lines>\n";
}

my ($output_file, $num_lines) = @ARGV;

open(my $fh, '>', $output_file) or die "Cannot create $output_file: $!\n";

print "Reading $num_lines locations...\n";

# set read mode
system("regwrite 0x2000200 0x1 >/dev/null 2>&1");

for (my $addr = 0; $addr < $num_lines; $addr++) {

    # Set BRAM address
    system("regwrite $mem_addr_reg $addr >/dev/null 2>&1");

    # Read registers
    my $lsb_res  = `regread $dout_reg_lsb 2>&1`;
    my $msb_res  = `regread $dout_reg_msb 2>&1`;
    my $ctrl_res = `regread $ctrl_out_reg 2>&1`;

    my $lsb_hex  = "00000000";
    my $msb_hex  = "00000000";
    my $ctrl_hex = "00";

    if ($lsb_res =~ /:\s*0x([0-9A-Fa-f]+)/) {
        $lsb_hex = uc(sprintf("%08s", $1));
        $lsb_hex =~ tr/ /0/;
    }

    if ($msb_res =~ /:\s*0x([0-9A-Fa-f]+)/) {
        $msb_hex = uc(sprintf("%08s", $1));
        $msb_hex =~ tr/ /0/;
    }

    if ($ctrl_res =~ /:\s*0x([0-9A-Fa-f]+)/) {
        my $tmp = uc(sprintf("%08s", $1));
        $tmp =~ tr/ /0/;
        $ctrl_hex = substr($tmp, -2);   # keep only lowest byte
    }

    # Just concatenate: ctrl + msb + lsb
    my $combined = $ctrl_hex . $msb_hex . $lsb_hex;

    print $fh "0x$combined\n";
}

close($fh);

print "Done. Output written to $output_file\n";