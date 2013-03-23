package Proj;

use strict;
use warnings;
use Cwd;

use Proj::Handler;

sub new {
  my ($package,%args) = @_;

  my $self = bless({
    conf => {%args},
    include => [ getcwd ],
    path => [],
    created => [],
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

  return $self->{tmpldir} . '.d';
}


sub _source_file_name {
  my ($self,$srcname) = @_;

  return __first_existing(map { join('/',$_,$self->{tmpldir}) }
                            map { ($_.'.tt', $_ ) }
                              join('/',@{ $self->{path} },$srcname),
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

  print STDERR "$message\n";
  foreach my $file_or_directory (@{ $self->{created} }) {
    remove_tree($file_or_directory,{verbose => 1});
  }

  return 1;
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
    my $handler = &{__PACKAGE__.'::'.$method};

    unless (defined &$handler) {
      warn "Undefined handler $method!\n";
    }
    else {
      $handler->($self,$arg,@children);
    }
  };
}

sub __run_hooks {
  my (@hooks) = @_;

  foreach my $hook (@hooks) {
    if (ref($hook) eq 'CODE') {
      $hook->();
    }
    else {
      qx{$hook};
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

sub create {
  my ($self,$template) = @_;

  $self->set_template($template);

  {
    package Proj::Template;

    my $tmplname = $self->{tmplname};

    unless (my $return = do $tmplname) {
      die "couldn't parse $tmplname: $@" if $@;
      die "cannot read $tmplname: $!" unless defined $return;
    }
  }

  no warnings 'once';
  __run_hooks($Proj::Template::before);
  {
    local $SIG{__DIE__} = defined $self->{error}
      ? sub { $self->{error}->($self,@_) }
      : sub { exit $self->_fail(@_); };

    $self->_create_tree(@{ $Proj::Template::tree });
  }
  __run_hooks($Proj::Template::after);
}

1;
