unit module Archive::Tar::PP;

use Archive::Tar::PP::Tar;

sub tar($n) is export {
  my $file-name = $n ~~ IO ?? $n !! $n.IO;
  Archive::Tar::PP::Tar.new(:$file-name);
}
