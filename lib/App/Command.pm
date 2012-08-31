package App::Command;
#ABSTRACT: Boilerplate for Applications

use strict;
use warnings;
use v5.10;

use Try::Tiny;
use Carp;
use Scalar::Util qw(reftype blessed);
use Log::Contextual qw(:log :dlog with_logger);

=method new( [ %config ] )

Create a new application instance. No initialization is executed.

=cut

sub new {
	my $class = shift;
	bless { @_ }, $class;
}

=method init

Initialize the application. Implement this method in youir subclass if needed.

=cut

sub init { }

=method parse_options( @ARGV )

Parse command line options and set configuration values. The general command
line syntax is assumed to be: 

    myapp <command> @args

In addition one can specify predefined options which by default are:

    --h, --help
	--v, --version
	-c FILE, --config FILE

Furthermore one can set arbitrary configuration values as key=value pairs.
Nested keys are possible separated with a dot. For instance

    myapp foo=bar doz.bar=2

results in the following configuration

    { foo => "bar", doz => { bar => 2 }

which could also be specified in a config file as 

    foo: bar
	doz:
	  bar: 2

=cut

sub parse_options {
	my $self = shift;

	local @ARGV = @_;

	require Getopt::Long;
	my $parser = Getopt::Long::Parser->new(
		config => [ "no_ignore_case", "pass_through" ],
	);

	$parser->getoptions(
		"h|help"	 => \$self->{help},
		"v|version"  => \$self->{version},
		"c|config=s" => \$self->{config},
	);

	my @args;
	while (defined(my $arg = shift @ARGV)) {
		if ($arg =~ /^([^=]+)=(.+)/) {
			my @path = split /\./, $1;
			my $hash = $self;
			while( @path > 1 ) {
				my $e = shift @path;
				$hash->{$e} //= { };
				$hash = $hash->{$e};
			}
			$hash->{ $path[0] } = $2 
				if (reftype($hash)||'') eq 'HASH';
		} else {
			push @args, $arg;
		}
	}

	$self->{command} = shift @args;
	$self->{args}   = \@args;
}

=method prepare

This internal method is called before execution, unless the config value
C<prepared> is set. When C<help> is set or the command is "help", the
application quits with usage information based on L<Pod::Usage>. When
C<version> is set or the command is "version", the application quits with its
name and version number.  Otherwise the methods reads configuration if a config
file is specified with C<config>, it enables a logger (see method L</logger>)
and initializes the application by calling L</init>.

You should not need to directory call this method.

=cut

sub prepare {
	my $self = shift;

	my $cmd = $self->{command} // '';

	if ($self->{help} or $cmd eq 'help') {
		require Pod::Usage;
		Pod::Usage::pod2usage(0);
	}

	if ($self->{version} or $cmd eq 'version') {
		require File::Basename;
		my ($name)  = File::Basename::fileparse($0);
		my $version = $self->VERSION // '(unknown version)';
		say "$name $version";
		exit;
	}

	if ($self->{config}) {

		# TODO: log this by using a default logger
		
		require YAML::Any;
		my $config = YAML::Any::LoadFile->( $self->{config} );

		while (my ($key,$value) = each %$config) {
			$self->{$key} //= $value;
		}
	}

	$self->logger( $self->{logger} );
	$self->logger->level( $self->{loglevel} || 'WARN' );

	with_logger $self->logger, sub { $self->init };

	$self->{prepared} = 1;
}

=method execute( [ $command, @args ] | @args )

Executes a command with some arguments. The command is taken from the
configuration value C<command> by default. 

This core method acts as front controller of an application. Commands, as
implemented by C<command_foo> methods, should only executed by the execute
method to ensure common error handling and logging.

=cut

sub execute {
	my $self = shift;

	my $cmd  = @_ ? shift : $self->{command};
	my @args = @_ ? @_ : @{$self->{args}||[]};

	$self->prepare unless $self->{prepared};

	croak "missing command" unless $cmd;

	my $method = "command_$cmd";
	croak "unknown command: $cmd" 
		unless $cmd =~ /^[a-z]+$/ and $self->can($method);

	with_logger $self->logger, sub {
		Dlog_trace { "execute $_" } $cmd, @args;
		try { 
			$self->$method( @args ); 
		} catch {
			log_error { $_ }
		}
	};
}

=method logger( [ $logger | [ { %config }, ... ] )

Configure a L<Log::Log4perl> logger, either directly or by passing logger
configuration. Logger configuration consists of an array reference with hashes
that each contain configuration of L<Log::Log4perl::Appender>.  The default
appender, as configured with C<logger(undef)> is equal to setting:

    logger([{
		class     => 'Log::Log4perl::Appender::Screen',
		threshold => 'WARN'
	}])

To simply log to a file, one can use:

	logger([{
		class     => 'Log::Log4perl::Appender::File',
		filename  => '/var/log/picaedit/error.log',
		threshold => 'ERROR',
		syswrite  => 1,
	})

Without C<threshold>, logging messages up to C<TRACE> are catched. To actually enable
logging, a default logging level is set, for instance

	logger->level('WARN');

Use C<logger([]) to disable all loggers.

You should not need to directory call this method but provide configuration
values C<logger> and C<loglevel>.

=cut

sub logger {
	my $self = shift;
	return $self->{log4perl} unless @_;

	if (blessed($_[0]) and $_[0]->isa('Log::Log4perl::Logger')) {
		return ($self->{log4perl} = $_[0]);
	}

	croak "logger configuration must be an array reference"
		unless !$_[0] or (reftype($_[0]) || '') eq 'ARRAY';

	my @config = $_[0] ? @{$_[0]} : ({
		class     => 'Log::Log4perl::Appender::Screen',
		threshold => 'WARN'
	});

	my $log = Log::Log4perl->get_logger( __PACKAGE__ );
	foreach my $c (@config) {
		my $app = Log::Log4perl::Appender->new( $c->{class}, %$c );
		my $layout = Log::Log4perl::Layout::PatternLayout->new( 
			$c->{layout} || "%d{yyyy-mm-ddTHH::mm} %p{1} %c: %m{chomp}%n" );
		$app->layout( $layout);
		$app->threshold( $c->{threshold} ) if exists $c->{threshold};
		$log->add_appender($app);
	}

	$log->trace( "new logger initialized" );

	return ($self->{log4perl} = $log);
}

1;

=head1 SYNOPSIS

	# implement your application
	package Your::App;
	use base 'App::Command';

	sub command_foo {
		my ($self,@argv) = @_;
		...
	}

	sub command_bar { 
		... 
	}

	# execute it as command line script
	my $app = Your::App->new;
	$app->parse_options(@ARGV);
	$app->execute;

	# execute it as backend
	my $app = Your::App->new( %config );

	$app->execute( @args ); # command in $config{command}
	$app->execute( $command, @args );

=head1 DESCRIPTION

App::Command provides a boilerplate for applications that can be executed both
from command line and as backend. The package provides a convenient wrapper for
initialization and configuration.

App::Command requires at least Perl 5.10.

=head1 SEE ALSO

Use L<Log::Contextual> for logging in your application. See L<Log::Log4perl>
for logging configuration.

This package was inspired by L<plackup>.

=cut
