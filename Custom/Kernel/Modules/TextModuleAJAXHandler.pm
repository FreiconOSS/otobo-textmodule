# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/
# Copyright (C) 2012-2020 Znuny GmbH, http://znuny.com/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

package Kernel::Modules::TextModuleAJAXHandler;

use strict;
use warnings;
use Data::Dumper;

sub new {
    my ($Type, %Param) = @_;

    # allocate new hash for object
    my $Self = { %Param };
    bless($Self, $Type);

    return $Self;
}

sub Run {
    my ($Self, %Param) = @_;
    # create needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    for my $Needed (qw(Subaction)) {
        $Param{$Needed} = $ParamObject->GetParam(Param => $Needed) || '';
        if (!$Param{$Needed}) {
            return $LayoutObject->ErrorScreen(Message => "Need $Needed!",);
        }
    }

    if ($Param{Subaction} eq 'Get') {
        return $Self->_Get(%Param);
    }

    if ($Param{Subaction} eq 'Widget') {
        return $Self->_Widget(%Param);
    }
}

sub _Widget {
    my ($Self, %Param) = @_;
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TextModuleObject = $Kernel::OM->Get('Kernel::System::TextModule');
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    for (qw(Frontend TypeID QueueID TicketID StateID CustomerUserID)) {
        $Param{$_} = $ParamObject->GetParam(Param => $_) || '';
    }

    my %Ticket;
    if ($Param{TicketID} && $Param{TicketID} ne 'undefined') {
        %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );
    }

    my $CustomerUser;
    if ($Param{Frontend} eq 'Customer') {
        $CustomerUser = $Self->{UserID};
    }
    elsif ($Param{CustomerUserID}) {
        $CustomerUser = $Param{CustomerUserID};
    }

    my %TextModules = $TextModuleObject->TextModuleList(
        %Ticket,
        Result         => 'HASH',
        UserLastname   => $Self->{UserLastname},
        UserFirstname  => $Self->{UserFirstname},
        TicketTypeID   => $Param{TypeID} || $Ticket{TypeID},
        QueueID        => $Param{QueueID} || $Ticket{QueueID},
        TicketStateID  => $Param{StateID} || $Ticket{StateID},
        Customer       => ($Param{Frontend} eq 'Customer') ? '1' : '',
        Public         => ($Param{Frontend} eq 'Public') ? '1' : '',
        Agent          => ($Param{Frontend} eq 'Agent') ? '1' : '',
        UserID         => ($Param{Frontend} eq 'Agent') ? $Self->{UserID} : '',
        CustomerUserID => $CustomerUser,
    );

    my $categoryTree = {};
    my $NoCategoryName = 'Ohne Kategorie';

    # Group permissions for user
    my %MemberOf = $GroupObject->PermissionUserGroupGet(
        UserID => $Self->{UserID},
        Type   => "rw",
    );

    for my $TextModuleID (keys %TextModules) {
        my $category = ($TextModules{$TextModuleID} || '');
        my @TreeParts = split /::/, ($category->{Category} || $NoCategoryName);

        my %TextModule = %{$TextModules{$TextModuleID}};

        my $HasPermission = $TextModuleObject->HasPermission(
            UserID       => $Self->{UserID},
            Category     => $TextModule{Category},
            NeededGroups => $TextModule{NeededGroups},
            NeededRole   => $TextModule{NeededRole},
        );

        if (!$HasPermission) {
            next;
        }

        my $currentTree = $categoryTree;

        foreach my $cp (@TreeParts) {
            if ($currentTree->{$cp}) {
                $currentTree = $currentTree->{$cp};
            } else {
                my $newNode = {};
                $currentTree->{$cp} = $newNode;
                $currentTree = $currentTree->{$cp};
            }
        }

        if ($currentTree->{"_leafs"}) {
            my $leafs = $currentTree->{"_leafs"};
            push @{$leafs}, $category;
        } else {
            my @leafs;
            push @leafs, $category;
            $currentTree->{"_leafs"} = \@leafs;
        }
    }

    my $out = '
            <div class="Header">
            <h2>Textbausteine</h2>
            <p style="margin-left: 4px;"><a href="#" style="color:gray;" id="ButtonExpandAll">Alles aufklappen</a> | <a href="#" style="color:gray;" id="ButtonCollapseAll">Alles zuklappen</a></p>
              <input type="text" name="searchfield" id="searchfield" style="width:95%;height:12px; font-size:10px;" placeholder="Suche"/>
                </div>
            <div class="Content" id="TextModulesTreeViewContainer"><ul class="TextModulesTreeView">';
    my @keys = keys %{$categoryTree};
    my @sortedKeys = sort @keys;

    my $UserID = $Self->{UserID} || '';
    
    foreach my $treeNode (@sortedKeys) {
        $out .= _buildTextModuleNode($UserID, $categoryTree->{$treeNode}, $treeNode, %MemberOf);
    }
    $out .= '</ul></div>';
    
    return $LayoutObject->Attachment(
        ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
        Content     => $out || "<br/>",
        Type        => 'inline',
        NoCache     => 1,
    );

}

sub _Get {
    my ($Self, %Param) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TextModuleObject = $Kernel::OM->Get('Kernel::System::TextModule');
    my $RichText = $ConfigObject->Get('Frontend::RichText');
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

    my $ID = $ParamObject->GetParam(Param => 'TextModuleID') || '';
    my $TicketID = $ParamObject->GetParam(Param => 'TicketID') || 0;
    my %Data = $TextModuleObject->TextModuleGet(
        ID => $ID,
    );

    my %Ticket;
    
    if ($TicketID) {
        %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 1,
            Silent        => 1,
        );
    }
    
    # replace placeholder in text and subject
    for my $DataKey (qw(TextModule Subject)) {

        next if !defined $Data{$DataKey};

        $Data{$DataKey} = $TemplateGeneratorObject->_Replace((
            Text     => $Data{$DataKey},
            Data     => $Param{Data} || {},
            RichText => ($DataKey eq 'TextModule') ? $RichText : 0,
            UserID   => $Self->{UserID},
            TicketID => $TicketID,
            TicketData => \%Ticket,
            Frontend => $Param{Frontend},
        ));
    }

    $Data{Subject} = '' if !$Data{Subject};
    $Data{TextModule} = '' if !$Data{TextModule};

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $LayoutObject->JSONEncode(
            Data => \%Data,
        ),
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _buildTextModuleNode {
    my ($UserID, $dataArray, $key, %MemberOf) = @_;
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    
    @{$dataArray->{'_leafs'}} = sort { alphanumSort($a->{'Name'}, $b->{'Name'}) } @{$dataArray->{'_leafs'}};

    my %Preferences = $UserObject->GetPreferences(
        UserID => $UserID,
    );
    
    my $TreeOpened = $Preferences{TextModuleTreeExpandedDefault} || 'false';
    my $out = '<li data-jstree=\'{"icon":"fa fa-folder-open-o", "opened":' . $TreeOpened . ',"selected":true}\'>' . $key . '<ul>';

    my @keys = keys %{$dataArray};
    my @sortedKeys = sort @keys;
    foreach my $dataRowKey (sort @sortedKeys) {
        if ($dataRowKey eq "_leafs") {
        } else {
            $out .= _buildTextModuleNode($UserID, $dataArray->{$dataRowKey}, $dataRowKey, %MemberOf);
        }
    }

    foreach (@{$dataArray->{"_leafs"}}) {
        $out .= '<li class="text_module_item" data-module="' . $_->{ID} . '">' . $_->{Name} . '</li>';
    }

    $out .= "</ul>\n";
    return $out;
}

sub alphanumSort {
    my ($a, $b) = @_;
    my @a = ($a =~ /(\d+|\D+)/g);
    my @b = ($b =~ /(\d+|\D+)/g);

    while (@a && @b) {
        my $a_part = shift @a;
        my $b_part = shift @b;

        if ($a_part =~ /\d/ && $b_part =~ /\d/) {
            return $a_part <=> $b_part if $a_part != $b_part;
        } else {
            return $a_part cmp $b_part if $a_part ne $b_part;
        }
    }
    return @a <=> @b;
}


1;
