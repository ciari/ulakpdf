<?php
// Test IdP user store. These accounts only exist for local development.
$config = [

    'admin' => [
        'core:AdminPassword',
    ],

    'example-userpass' => [
        'exampleauth:UserPass',

        'user1:user1pass' => [
            'uid'                    => ['user1'],
            'eduPersonPrincipalName' => ['user1@stirling.local'],
            'eduPersonAffiliation'   => ['faculty', 'member'],
            'mail'                   => ['user1@stirling.local'],
            'displayName'            => ['Faculty One'],
            'givenName'              => ['Faculty'],
            'sn'                     => ['One'],
            'cn'                     => ['Faculty One'],
        ],

        'user2:user2pass' => [
            'uid'                    => ['user2'],
            'eduPersonPrincipalName' => ['user2@stirling.local'],
            'eduPersonAffiliation'   => ['student', 'member'],
            'mail'                   => ['user2@stirling.local'],
            'displayName'            => ['Student Two'],
            'givenName'              => ['Student'],
            'sn'                     => ['Two'],
            'cn'                     => ['Student Two'],
        ],
    ],

];
