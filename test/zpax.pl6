use lib '../lib';
use Archive::Tar::PP;
use Data::Dump;

sub no (Buf $x) {
  "\|{$x.decode('utf8').subst(/"\0"|"\n"|"\r"/, '.', :g).subst(/(. ** 16)/, { $0 ~ "|\n|" }, :g)}\|";
}

my $a = read-tar('pax.tar');

say Dump @($a.ls);
