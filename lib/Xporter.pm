#!/usr/bin/perl
BEGIN { require $_.".pm" && $_->import for qw(strict warnings) }
# vim=:SetNumberAndWidth
=encoding utf-8

=head1 NAME

Xporter - Alternative Exporter with persistant defaults & auto-ISA

=head1 VERSION

Version "0.0.12"

=cut

{ package Xporter;
	BEGIN { require $_.".pm" && $_->import for qw(strict warnings) }
	our $VERSION='0.0.13';
	our @CARP_NOT;
	use mem(@CARP_NOT=(__PACKAGE__));
	# 0.0.13 - Bug fix in string version compare -- didn't add leading
	#          zeros for numeric compares;
	# 0.0.12 - Add version tests to test 3 forms of version: v-string,
	# 					numeric version, and string-based version.
	# 					If universal method $VERSION doesn't exist, call our own
	# 					method.
	# 0.0.11 - Add a Configure_depends to see if that satisfies the one 
	#          test client that is broken (sigh)
	# 0.0.10 - Remove P from another test (missed one);  Having to use
	#         replacement lang features is torture  on my RSI
	# 0.0.9 - add alternate version format for ExtMM(this system sucks)
	#       - remove diagnostic messages from tests (required P)
	# 0.0.8 - add current dep for BUILD_REQ of ExtMM
	# 0.0.7 - 'require' version# bugfix
	# 0.0.6 - comment cleanup; Change CONFIGURE_REQUIRES to TEST_REQUIRES
	# 0.0.5 - export inheritance test written to highlight a problem area
	# 			- problem area addessed; converted to use efficient jump table
	#	0.0.4 - documentation additions;
	#				- added tests & corrected any found problems
	#	0.0.3 - added auto-ISA-adding (via push) when this mod is used.
	#	      - added check for importing 'import' to disable auto-ISA-add
	# 0.0.2	- Allow for "!" as first arg to import to turn off default export
	# 				NOTE: defaults are defaults when using EXPORT_OK as well;
	# 							One must specifically disable defaults to turn them off.
	# 0.0.1	- Initial split of code from iomon
	#
	#require 5.8.0;
	
	# Alternate export-import method that doesn't undefine defaults by 
	# default

	sub add_to_caller_ISA($$) {
		my ($pkg, $caller) = @_;
			
		if ($pkg eq __PACKAGE__) { no strict 'refs';
			unshift @{$caller."::ISA"}, $pkg unless grep /$pkg/, @{$caller."::ISA"};
		}
	}

	sub cmp_ver($$) {
		my ($v1, $v2) = @_;
		for (my $i=0; $i<@$v2 && $i<@$v1; ++$i) {
			my ($v1p, $v1_num, $v1s) = ($v1->[$i] =~ /^([^\d]*)(\d+)([^\d]*)$/);
			my ($v2p, $v2_num, $v2s) = ($v2->[$i] =~ /^([^\d]*)(\d+)([^\d]*)$/);
			my $maxlen = $v1_num > $v2_num ? $v1_num : $v2_num;
			my $r =	sprintf("%s%0*d%s", $v1p||"", $maxlen, $v1_num, $v1s||"") cmp
							sprintf("%s%0*d%s", $v2p||"", $maxlen, $v2_num, $v2s||"");
			return -1 if $r<0;
		}
		return 0;
	}


	sub _version_specified($$;$) {
		my ($pkg, $requires) = @_;
		my $pkg_ver;
		{	no strict 'refs';
			$pkg_ver = ${$pkg."::VERSION"} || '(undef)';
		}
		my @v1=split /_|\./, $pkg_ver;
		my @v2=split /_|\./, $requires;
		if (@v1>2 || @v2>2) {
			return if cmp_ver(\@v1, \@v2) >= 0;
		} else {
			return if $pkg_ver && ($pkg_ver cmp $requires)>=0;
			return if $pkg_ver ne '(undef)' && $pkg_ver >= $requires;
		}
		require Carp; 
		Carp::croak(sprintf "module %s %s required. This is only %s", $pkg, $requires, $pkg_ver);
	}


	our %exporters;

	sub import { 
		my $pkg			= shift;
		my ($caller, $fl, $ln)	= (caller);
		no strict 'refs';

		#*{$caller."::import"}= \&{__PACKAGE__."::import"} if !exists ${$caller."::import"}->{CODE};

		if (@_ && $_[0] && $_[0] =~ /^(v?[\d\._]+)$/) {
			my @t=split /\./, $_[0];
			no warnings;
			if ($pkg->can("VERSION") && @t<3 && $1 ) { 
				$pkg->VERSION($1) }
			else {
				_version_specified($pkg, $1); }
			shift;
		}

		if ($pkg eq __PACKAGE__) {		# we are exporting

			if (@_ && $_[0] eq q(import)) {
				no strict q(refs);
				*{$caller."::import"} = \*{$pkg."::import"};
			} else {
				add_to_caller_ISA($pkg, $caller);
			}
			$exporters{$caller} = 1;
			return 1;
		}

		my ($export, $exportok, $exporttags);

		{ no strict q(refs);
			$export = \@{$pkg."::"."EXPORT"} || [];
			$exportok = \@{$pkg."::"."EXPORT_OK"} || [];
			$exporttags = \%{$pkg."::"."EXPORT_TAGS"};
		}

		
		my @allowed_exports = (@$export, @$exportok);

		if (@_ and $_[0] and  $_[0] eq '!' 	|| $_[0] eq '-' ) {
			$export=[];
			shift @_;
		}

		for (@_) {
			push @$export, $_ if grep { /$_/ } @allowed_exports;
		}

		my $tc2proto = {'&' => '&', '$'  => '$', '@' => '@',
										'%'	=> '%', '*' => '*', };

		for(@$export) {
			next unless $_;
			my $type = substr $_, 0, 1;
			if (exists $tc2proto->{$type}) { $_ = substr($_,1) } 
			elsif ($type =~ /\w/) { $type='&' }
			else { require Carp; Carp::croak("Unknown type $type in $_"); }
			my $colon_name	= "::" . $_ ;
			my ($exf, $imf)	= ( $pkg . $colon_name, $caller . $colon_name);
			no strict q(refs);
			my $case = {
				'&'	=>	\&$exf,
				'$'	=>	\$$exf,
				'@' =>	\@$exf,
				'%' =>	\%$exf,
				'*'	=>	 *$exf};
			*$imf = $case->{$type};
		}
	}
1}


=head1 SYNOPIS

In the "Exporting" module:

  { package module_adder [optional version]; 
	  use warnings; use strict;
    use mem;			# to allow using module in same file
    our (@EXPORT, @EXPORT_OK);
    our $lastsum;
    our @lastargs;
    use Xporter(@EXPORT=qw(adder $lastsum @lastargs), 
            		@EXPORT_OK=qw(print_last_result));

    sub adder($$) {@lastargs=@_; $lastsum=$_[0]+$_[1]}
    sub print_last_result () {
      use P;    # using P allows answer printed or as string
      if (@lastargs && defined $lastsum){
        P "%s = %s\n", (join ' + ' , @lastargs), $lastsum;
      }
    }
  }

In C<use>-ing module (same or different file)

  package main;  use warnings; use strict;
  use module_adder qw(print_last_result);

  adder 4,5;

Printing output:

  print_last_result();

  #Result:
  
  4 + 5 = 9

(Or in a test:)
	
  ok(print_last_result eq "4 + 5 = 9", "a pod test");

=head1 DESCRIPTION

C<Xporter> provides Export functionality similar to Exporter, with
some different behaviors to simplify common cases.

One primary difference, in C<Xporter> is that the default EXPORT list
remains the default EXPORT list unless you specifically ask for it
to not be included.

In Exporter, if you ask for an addition export from the EXPORT_OK
list, you automatically lose your I<defaults>.  The theory here being
that if you want something extra you shouldn't be required to lose
your default list.  The default list is easily enough NOT included
by specifying '-' or '!' as the first parameter in the client's 
import list. 

=head2 Example

Suppose your module has exports:

  our (@EXPORT, @EXPORT_OK);
  use Xporter(@EXPORT=qw(one $two %three @four), 
              @EXPORT_OK=qw(&five));

In the using module, to only import symbols 'two' and 'five', 
one would use:

  use MODULENAME qw(! $two five);

That negates the default EXPORT list, and lets you selectively
import the values you want from either the default or the OK list
(modules in the default list don't need to be relisted in the OK list
as it is presumed that they were OK to be exported or they would not
have been defaults).

Other functions of Exporter are not currently implemented though
may appear in later versions should those features be needed.

Listing the EXPORT and EXPORT_OK assignments as params to Xporter 
allow their types to be available to importing modules at compile time.

=head2 Version Strings

Version strings in the form of a decimal fraction, (0.001001), a
V-String (v1.2.1 with no quotes), or a version string
('1.1.1' or 'v1.1.1') are supported, though note, versions in
different formats are not interchangeable.  The format used in 
a modules documentation should be used.






