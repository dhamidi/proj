# Copyright (C) 2013 Dario Hamidi <dario.hamidi@gmail.com>.
#
# This module is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
package Proj;

use strict;
use warnings;
use Cwd;

use Proj::Handler;
use Proj::Template;

our $VERSION = 1.00;

sub new {
  my ($package,%args) = @_;

  my $self = bless({
    conf => {%args},
    include => [ getcwd ],
    created => [],
    basedir => '',
    tmpldir => '',
    tmplname => '',
  },$package);

  if (defined $args{-include}) {
    push @{ $self->{include} }, @{ $args{-include} };
  }

  if (defined $args{-error}) {
    $self->{error} = $args{-error};
  }

  delete $args{$_} foreach grep { /^-/ } keys %args;

  return $self;
};

sub __first_existing {
  use List::Util qw(first);
  return first { -e $_ } @_;
}

sub _template_file_name {
  my ($self,$tmpl) = @_;

  use List::Util qw(first);

  return __first_existing(map { join('/',$_,$tmpl) }
                            @{ $self->{include}});
}

sub _template_directory {
  my ($self) = @_;

  return $self->{tmplname} . '.d';
}


sub _source_file_name {
  my ($self,$srcname) = @_;

  return __first_existing(map { $self->{tmpldir}.'/' . $_ }
                            map { ($_.'.tt', $_ ) }
                              $self->curdir . $srcname,
                              $srcname);
}

sub __value {
  my ($scalar) = @_;

  return ref $scalar eq 'CODE' ? $scalar->() : $scalar;
}

sub _register {
  my ($self,$filename) = @_;

  unshift @{ $self->{created} },$filename;

  return $self;
}

sub _fail {
  my ($self,$message) = @_;

  use File::Path qw(remove_tree);

  chdir $self->{basedir} if $self->{basedir};

  print STDERR "$message\n";
  foreach my $file_or_directory (@{ $self->{created} }) {
    remove_tree($file_or_directory,{verbose => 1});
  }

  return 1;
}

sub _diag {
  my ($self,$message) = @_;

  print $message,"\n";
}

sub _path {
  my ($self) = @_;

  return join('/',@{ $self->{path} });
}

sub _create_tree {
  my ($self,@branches) = @_;

  foreach my $branch (@branches) {
    my ($method,$arg,@children) = map { __value($_) } @{ $branch };
    no strict 'refs';
    my $handler = \&{'Proj::Handler::'.$method};

    unless (defined &$handler) {
      warn "Undefined handler $method!\n";
    }
    else {
      $handler->($self,$arg,@children);
    }
  };
}

sub __run_hooks {
  my ($hooks) = @_;

  foreach my $hook (@{ $hooks }) {
    next unless defined $hook;
    if (ref($hook) eq 'CODE') {
      $hook->();
    }
    else {
      system($hook);
    }
  }
}

sub _set_template_directory {
  my ($self) = @_;

  my $tmpldir = $self->_template_directory;

  unless ($tmpldir) {
    die "$tmpldir: $!\n" unless -x $tmpldir && -d _;
  }

  $self->{tmpldir} = $tmpldir;
}

sub set_template {
  my ($self,$template) = @_;

  my $tmplname = $self->_template_file_name($template);

  unless ($tmplname) {
    die "Cannot find \"$template\".\nSearched:\n"
      .join("\n",@{ $self->{include} })."\n";
  }

  $self->{tmplname} = $tmplname;

  $self->_set_template_directory();
}

sub set_path {
  my ($self,$path) = @_;

  $path ||= getcwd;

  $self->{path} = [split '/',$path];

  return $self;
}

sub curdir {
  my ($self) = @_;

  my $rel = substr($self->_path,length($self->{basedir})) . '/';
  $rel =~ s{^/}{};

  return $rel;
}

sub create {
  my ($self,$template) = @_;

  $self->{basedir} = getcwd;
  $self->set_template($template);

  $self->set_path() unless ref $self->{path} eq 'ARRAY';

  {
    package Proj::Template;

    my $tmplname = $self->{tmplname};

    local $Proj::Template::PROJ = $self;

    unless (my $return = do $tmplname) {
      die "couldn't parse $tmplname: $@" if $@;
      die "cannot read $tmplname: $!" unless defined $return;
    }
  }

  __run_hooks($Proj::Template::before);
  {
    local $SIG{__DIE__} = defined $self->{error}
      ? sub { $self->{error}->($self,@_) }
      : sub { exit $self->_fail(@_); };

    $self->_create_tree(@{ $Proj::Template::tree })
      if $Proj::Template::tree;
  }
  __run_hooks($Proj::Template::after);
}

sub load {
  my ($self,$filename) = @_;

  local *defhandler = sub {
    my ($name,$code) = @_;
    no strict 'refs';
    *{"Proj::Handler::${name}"} = $code;
  };

  my $return;
  unless ($return = do $filename) {
    die "couldn't parse $filename: $@" if $@;
    die "cannot read $filename: $!" unless defined $return;
  }

  return $return;
}
1;
