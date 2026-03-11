open(R1,"imem_hex_t0.txt");
open(R2,"imem_hex_t1.txt");
open(R3,"imem_hex_t2.txt");
open(R4,"imem_hex_t3.txt");

open(W1,">","output_imem.hex");

for (my $i = 0; $i < 512; $i++) {
 $l = <R1>;
 chomp $l;
if (!defined $l){
print W1 "00000000\n";
} else {
 print W1 "$l\n";
}
}

close R1;

for (my $i = 0; $i < 512; $i++) {
 $l = <R2>;
 chomp $l;
if (!defined $l){
print W1 "00000000\n";
} else {
 print W1 "$l\n";
}

}

close R2;

for (my $i = 0; $i < 512; $i++) {
 $l = <R3>;
 chomp $l;
if (!defined $l){
print W1 "00000000\n";
} else {
 print W1 "$l\n";
}

}

close R3;

for (my $i = 0; $i < 512; $i++) {
 $l = <R4>;
 chomp $l;
if (!defined $l){
print W1 "00000000\n";
} else {
 print W1 "$l\n";
}

}

close R4;


