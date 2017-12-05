unit module Archive::Tar::PP;

use Archive::Tar::PP::Tar;
use Archive::Tar::PP::Util;

sub new-tar(IO() $file-name) is export {
  Archive::Tar::PP::Tar.new(:$file-name);
}

sub read-tar(IO() $file-name) is export {
  die "Could not find tar file {$file-name.relative}"
    unless $file-name ~~ :e;
  Archive::Tar::PP::Tar.new(:$file-name, :buffer(read-existing-tar($file-name)));
}
