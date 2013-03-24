package Proj::Template;

use strict;
use warnings;

our $PROJ;
our ($before,$after,$tree);   # used in template

sub extends {
  my (@templates) = @_;

  warn "Cannot extend in this context.\n"
    unless ref($PROJ) eq 'Proj';

  foreach my $template (@templates) {
    $PROJ->create($template);
  }
}
1;
