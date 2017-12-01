unit module Archive::Tar::PP;

use Archive::Tar::PP::Tar;
use Archive::Tar::PP::Util;

sub new-tar($n) is export {
  my $file-name = $n ~~ IO ?? $n !! $n.IO;
  Archive::Tar::PP::Tar.new(:$file-name);
}

sub read-tar($n) is export {
  my $file-name = $n ~~ IO ?? $n !! $n.IO;
  die "Could not find tar file {$file-name.relative}"
    unless $file-name ~~ :e;
  Archive::Tar::PP::Tar.new(:$file-name, :buffer(read-existing-tar($file-name)));
}
