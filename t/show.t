#!/usr/bin/perl -w

use strict;
use warnings;
use v5.10;
use Test::More;
use App::Sqitch;
use Path::Class;
use Test::Exception;
use Locale::TextDomain qw(App-Sqitch);
use Test::MockModule;
use lib 't/lib';
use MockOutput;

my $CLASS = 'App::Sqitch::Command::show';
require_ok $CLASS or die;

isa_ok $CLASS, 'App::Sqitch::Command';
can_ok $CLASS, qw(execute);

is_deeply [$CLASS->options], [
], 'Options should be correct';

my $sqitch = App::Sqitch->new(
    plan_file => file(qw(t pg sqitch.plan)),
    top_dir   => dir(qw(t pg)),
    _engine   => 'pg',
);

isa_ok my $show = $CLASS->new(sqitch => $sqitch), $CLASS;
ok my $change = $sqitch->plan->get('users'), 'Get a change';

# Start with the change.
ok $show->execute( change => $change->id ), 'Find change by id';
is_deeply +MockOutput->get_emit, [[ $change->info ]],
    'The change info should have been emitted';

# Try by name.
ok $show->execute( change => $change->name ), 'Find change by name';
is_deeply +MockOutput->get_emit, [[ $change->info ]],
    'The change info should have been emitted again';

# What happens for something unknonwn?
throws_ok { $show->execute( change => 'nonexistent' ) } 'App::Sqitch::X',
    'Should get an error for an unknown change';
is $@->ident, 'show', 'Unknown change error ident should be "show"';
is $@->message, __x('Unknown change "{change}"', change => 'nonexistent'),
    'Should get proper error for unknown change';

# Let's find it by tag.
my $tag = ($change->tags)[0];
ok $show->execute( change => $tag->id ), 'Find change by tag id';
is_deeply +MockOutput->get_emit, [[ $change->info ]],
    'The change info should have been emitted';

# And the tag name.
ok $show->execute( change => $tag->format_name ), 'Find change by tag';
is_deeply +MockOutput->get_emit, [[ $change->info ]],
    'The change info should have been emitted';

# Great, let's look a the tag itself.
ok $show->execute( tag => $tag->id ), 'Find tag by id';
is_deeply +MockOutput->get_emit, [[ $tag->info ]],
    'The tag info should have been emitted';

ok $show->execute( tag => $tag->name ), 'Find tag by name';
is_deeply +MockOutput->get_emit, [[ $tag->info ]],
    'The tag info should have been emitted';

ok $show->execute( tag => $tag->format_name ), 'Find tag by formatted name';
is_deeply +MockOutput->get_emit, [[ $tag->info ]],
    'The tag info should have been emitted';

# Try an invalid tag.
throws_ok { $show->execute( tag => 'nope') } 'App::Sqitch::X',
    'Should get errof for non-existent tag';
is $@->ident, 'show', 'Unknown tag error ident should be "show"';
is $@->message, __x('Unknown tag "{tag}"', tag => 'nope' ),
    'Should get proper error for unknown tag';

# Also an invalid sha1.
throws_ok { $show->execute( tag => '7ecba288708307ef714362c121691de02ffb364d') }
    'App::Sqitch::X',
    'Should get errof for non-existent tag ID';
is $@->ident, 'show', 'Unknown tag ID error ident should be "show"';
is $@->message, __x('Unknown tag "{tag}"', tag => '7ecba288708307ef714362c121691de02ffb364d' ),
    'Should get proper error for unknown tag ID';

# Now let's look at files.
ok $show->execute(deploy => $change->id), 'Show a deploy file';
is_deeply +MockOutput->get_emit, [[ $change->deploy_file->slurp(iomode => '<:raw') ]],
    'The deploy file should have been emitted';

ok $show->execute(revert => $change->id), 'Show a revert file';
is_deeply +MockOutput->get_emit, [[ $change->revert_file->slurp(iomode => '<:raw') ]],
    'The revert file should have been emitted';

# Nonexistent verify file.
throws_ok { $show->execute( verify => $change->id ) } 'App::Sqitch::X',
    'Should get error for nonexistent varify file';
is $@->ident, 'show', 'Nonexistent file error ident should be "show"';
is $@->message, __x('File "{path}" does not exist', path => $change->verify_file ),
    'Should get proper error for nonexistent file';

# Now try invalid args.
my $mock = Test::MockModule->new($CLASS);
my @usage;
$mock->mock(usage => sub { shift; @usage = @_; die 'USAGE' });
throws_ok { $show->execute } qr/USAGE/, 'Should get usage for missing params';
is_deeply \@usage, [], 'Nothing should have been passed to usage';

# Now an unknown type.
throws_ok { $show->execute(foo => 'bar') } 'App::Sqitch::X',
    'Should get error for uknown type';
is $@->ident, 'show', 'Unknown type error ident should be "show"';
is $@->message,  __x(
    'Unknown object type "{type}',
    type => 'foo',
), 'Should get proper error for unknown type';


done_testing;
