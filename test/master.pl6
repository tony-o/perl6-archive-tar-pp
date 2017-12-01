use lib '../lib';
use Archive::Tar::PP::Util;

sub no (Buf $x) {
  "\|{$x.decode('utf8').subst(/"\0"|"\n"|"\r"/, '.', :g).subst(/(. ** 16)/, { $0 ~ "|\n|" }, :g)}\|";
}

my $a = read-tar('master.tar'.IO);

.say for $a.map({ $_<name> ~ "\n" ~ no($_<buffer>) ~ "\n" });
