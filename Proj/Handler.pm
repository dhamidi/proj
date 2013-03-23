package Proj::Handler;

use strict;
use warnings;
use Template;

my $TEMPLATE = Template->new({
  POST_CHOMP => 1,
  ABSOLUTE => 1,
});

sub dir {
  my ($proj,$arg,@children) = @_;

  push @{ $proj->{path} }, $arg;
  my $path = $proj->_path;

  unless (-e $path) {
    mkdir $path or $proj->_fail("$path: $!");
    $proj->_register($path);
  }
  chdir $path;

  $proj->_create_tree(@children);

  pop @{ $proj->{path} };
  chdir $proj->_path;
}

sub file {
  my ($proj,$arg,@children) = @_;

  my $options = $children[0] || { overwrite => 0 };

  if (-e $arg) {
    if ($options->{overwrite}) {
      warn "overwrite $arg\n";
    }
    else {
      warn "exists $arg\n";
      return;
    }
  }

  my $fname = $proj->_source_file_name($arg);
  unless ($fname) {
    warn "unknown $arg\n";
    return;
  }

  if ((split '/',$fname)[-1] eq "$arg.tt") {
    $TEMPLATE->process($fname,$proj->{conf},$arg)
      || warn "$fname: " . $TEMPLATE->error;
  }
  else {
    use File::Copy;
    copy($fname,$arg) or $proj->_fail("Copy failed: $!");
  }
}

sub http {
  my ($proj,$arg,@children) = @_;

  use LWP::Simple;
  use File::Copy;

  $arg = 'http://'.$arg unless $arg =~ m{^http[s]?://};

  my ($fname) = ($arg =~ m{/([^?/ ]+?)(?:\?.*)?$});
  $fname = $proj->_source_file_name($fname) || $proj->{tmpldir}.'/'.$fname;
  my $dest  = $children[0] || (split '/',$fname)[-1];

  my $ret = mirror($arg,$fname);
  if ($ret == RC_OK) {
    warn "get $arg\n";
  }
  elsif ($ret == RC_NOT_MODIFIED) {
    warn "keep $arg\n";
  }
  else {
    warn "Failed to mirror $arg\n";
  }

  copy($fname,$dest) or $proj->_fail("Copy failed: $!");
}

1;
