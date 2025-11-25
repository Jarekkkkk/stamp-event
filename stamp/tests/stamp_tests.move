#[test_only]
module stamp::stamp_tests {
    use stamp::stamp::{Self, AdminCap, Config, Stamp};
    use std::ascii;
    use sui::{package::Publisher, test_scenario as ts};

    // Test collection type
    public struct TestCollection has drop {}

    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;
    const USER4: address = @0x4;
    const USER5: address = @0x5;
    const USER6: address = @0x6;
    const USER7: address = @0x7;
    const USER8: address = @0x8;
    const USER9: address = @0x9;
    const USER10: address = @0x10;

    #[test]
    fun test_create_event_collection_and_mint_for_multiple_accounts() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize the module
        {
            let ctx = ts::ctx(&mut scenario);
            stamp::init_for_testing(ctx);
        };

        // Admin creates an event
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::new_event(
                &mut config,
                &admin_cap,
                ascii::string(b"Test Event"),
                ascii::string(b"A test event for unit testing"),
                ascii::string(b"https://example.com/test-event.png"),
                100,
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        // Admin creates a collection
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let mut publisher = ts::take_from_sender<Publisher>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            stamp::new_collection<TestCollection>(
                &mut config,
                &mut publisher,
                ctx,
            );

            ts::return_to_sender(&scenario, publisher);
            ts::return_shared(config);
        };

        // Mint stamps for 10 different accounts
        let users = vector[USER1, USER2, USER3, USER4, USER5, USER6, USER7, USER8, USER9, USER10];
        let mut i = 0;

        while (i < users.length()) {
            let user = users[i];
            ts::next_tx(&mut scenario, ADMIN);
            {
                let mut config = ts::take_shared<Config>(&scenario);
                let ctx = ts::ctx(&mut scenario);

                stamp::mint_to<TestCollection>(
                    &mut config,
                    ascii::string(b"Test Event"),
                    user,
                    ctx,
                );

                ts::return_shared(config);
            };
            i = i + 1;
        };

        // Verify each user received their stamp
        i = 0;
        while (i < users.length()) {
            let user = users[i];
            ts::next_tx(&mut scenario, user);
            {
                let stamp = ts::take_from_sender<Stamp<TestCollection>>(&scenario);

                // Verify stamp properties
                let mut comp = ascii::string(b"Test Event#");
                comp.append((i + 1).to_string().to_ascii());
                assert!(stamp.get_stamp_name() == comp, 0);
                assert!(stamp.get_stamp_points() == 100, 1);
                assert!(stamp.get_stamp_event() == ascii::string(b"Test Event"), 2);
                assert!(
                    stamp.get_stamp_description() == ascii::string(b"A test event for unit testing"),
                    3,
                );
                assert!(
                    stamp.get_stamp_image_url() == ascii::string(b"https://example.com/test-event.png"),
                    4,
                );

                ts::return_to_sender(&scenario, stamp);
            };
            i = i + 1;
        };

        ts::end(scenario);
    }

    #[test]
    fun test_event_management() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize the module
        {
            let ctx = ts::ctx(&mut scenario);
            stamp::init_for_testing(ctx);
        };

        // Create initial event
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::new_event(
                &mut config,
                &admin_cap,
                ascii::string(b"Initial Event"),
                ascii::string(b"Initial description"),
                ascii::string(b"https://example.com/initial.png"),
                50,
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        // Update event description
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::update_event_description(
                &mut config,
                &admin_cap,
                ascii::string(b"Initial Event"),
                ascii::string(b"Updated description"),
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        // Update event image URL
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::update_event_image_url(
                &mut config,
                &admin_cap,
                ascii::string(b"Initial Event"),
                ascii::string(b"https://example.com/updated.png"),
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        // Update event points
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::update_event_points(
                &mut config,
                &admin_cap,
                ascii::string(b"Initial Event"),
                75,
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        // Update event name
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::update_event_name(
                &mut config,
                ascii::string(b"Initial Event"),
                ascii::string(b"Updated Event"),
                &admin_cap,
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::stamp::stamp::EDuplicateEventName)]
    fun test_duplicate_event_name_fails() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize the module
        {
            let ctx = ts::ctx(&mut scenario);
            stamp::init_for_testing(ctx);
        };

        // Create first event
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::new_event(
                &mut config,
                &admin_cap,
                ascii::string(b"Duplicate Event"),
                ascii::string(b"First event"),
                ascii::string(b"https://example.com/first.png"),
                100,
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        // Try to create event with same name - should fail
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::new_event(
                &mut config,
                &admin_cap,
                ascii::string(b"Duplicate Event"),
                ascii::string(b"Second event"),
                ascii::string(b"https://example.com/second.png"),
                200,
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        ts::end(scenario);
    }

    #[test, expected_failure(abort_code = ::stamp::stamp::ENotManager)]
    fun test_non_manager_cannot_mint() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize the module
        {
            let ctx = ts::ctx(&mut scenario);
            stamp::init_for_testing(ctx);
        };

        // Admin creates an event
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            stamp::new_event(
                &mut config,
                &admin_cap,
                ascii::string(b"Test Event"),
                ascii::string(b"A test event"),
                ascii::string(b"https://example.com/test.png"),
                100,
            );

            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(config);
        };

        // Non-manager tries to mint - should fail
        ts::next_tx(&mut scenario, USER1);
        {
            let mut config = ts::take_shared<Config>(&scenario);
            let ctx = ts::ctx(&mut scenario);

            stamp::mint_to<TestCollection>(
                &mut config,
                ascii::string(b"Test Event"),
                USER1,
                ctx,
            );

            ts::return_shared(config);
        };

        ts::end(scenario);
    }
}
