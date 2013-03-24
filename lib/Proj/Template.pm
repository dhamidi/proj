# Copyright (C) 2013 Dario Hamidi <dario.hamidi@gmail.com>.
#
# This module is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
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
