package Proj;

use strict;
use warnings;
use File::Spec;

{
  package Proj::Context;
  use File::Spec;
  use Cwd;

  sub new {
    my ($package,%args) = @_;

    $args{path} ||= getcwd;
    $args{dirstack} = [$args{path}];

    my $self = bless(\%args,$package);

    return $self;
  }

  sub path {
    my ($self) = @_;

    return $self->{path};
  }

  sub file {
    my ($self,$name) = @_;

    return File::Spec->catfile($self->path,$name);
  }

  sub pushd {
    my ($self,$dir) = @_;

    unless (File::Spec->file_name_is_absolute( $dir ) ) {
      $dir = File::Spec->catdir($self->path,$dir);
    }

    push @{$self->{dirstack}},$dir;
    chdir $dir;
    $self->{path} = $dir;

    return $self;
  }

  sub popd {
    my ($self) = @_;

    my $top = pop @{ $self->{dirstack} };
    my $path = $self->{dirstack}->[0];
    chdir $path;
    $self->{path} = $path;

    return $top;
  }

  sub srcpath {
    my ($self,$path) = @_;

    if (@_ > 1) { $self->{srcpath} = $path; return $self; }
    else { return $self->{srcpath};}
  }

  sub basedir {
    my ($self) = @_;

    return $self->{dirstack}->[0];
  }

  sub template {
    use List::Util qw(first);

    my ($self,$relpath) = @_;

    my @candidates = (
      File::Spec->rel2abs( $relpath, $self->srcpath ),
      (File::Spec->splitdir($relpath))[-1],
    );

    return first { -r $_ } map {
      (map { File::Spec->catfile($self->srcpath,$_) } $_,"$_.tmpl")
    } @candidates;
  }
}

{
  package Proj::Handler;

  sub define {
    my ($name,$code) = @_;
    no strict 'refs';
    *$name = sub {
      $code->(map { ref $_ eq 'CODE'? $_->() : $_ } @_);
    };
  }

  define file => sub {
    use File::Spec;

    my ($c,$fname) = @_;

    $fname = $c->file($fname);

    File::Spec->abs2rel($fname, $c->basedir);
    print STDERR "$fname\n";
  };

  define dir => sub {
    my ($c,$dname,@children) = @_;

    my $path = $c->{context}->file($dname);
    mkdir $path;
    $c->context->pushd($path);
    $c->create(\@children);
    $c->context->popd();
  };

  define shell => sub {
    my ($c,$command,@arguments) = @_;
    local $" = " ";
    system($command,@arguments);
  }
}

sub new {
  my ($package,$args) = @_;

  my $self = bless({},$package);

  return $self->init($args);
}

sub init {
  my ($self,$args) = @_;

  $args->{context} ||= {};

  $self->{context} = Proj::Context->new(%{$args->{context}});
  $self->{path}    = $args->{path};

  return $self;
}

sub context {
  my ($self) = @_;

  return $self->{context};
}

sub find {
  use List::Util qw(first);

  my ($self,$template) = @_;

  my @candidates = map {
    File::Spec->catfile($_,$template);
  } @{ $self->{path} };

  return first { -r $_ } @candidates;
}

sub create {
  my ($self,$tree) = @_;
  foreach my $branch (@{ $tree }) {
    no strict 'refs';

    my $handler = $branch->[0];

    $handler = \&{"Proj::Handler::$handler"};
    unless (defined &$handler) {
      warn "Undefined handler: ".$branch->[0]."\n";
    } else {
      $handler->($self,@{$branch}[1..$#{$branch}]);
    }
  }
}

sub main {
  use Cwd;
  my $p = Proj->new({
    path => [ getcwd ],
  });

  $p->create([[dir => 'hello',
               [file =>'world']]]);
}

1;
