/*
 * SPDX-FileCopyrightText: 2026 NewPipe contributors <https://newpipe.net>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

package org.schabi.newpipe.util;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.schabi.newpipe.extractor.channel.ChannelInfoItem;
import org.schabi.newpipe.extractor.stream.ContentAvailability;
import org.schabi.newpipe.extractor.stream.StreamInfoItem;
import org.schabi.newpipe.extractor.stream.StreamType;

public class ContentAvailabilityFilterTest {
    private static StreamInfoItem stream(final ContentAvailability availability) {
        final StreamInfoItem item = new StreamInfoItem(
                0, "https://example.com/watch?v=test", "test", StreamType.VIDEO_STREAM);
        item.setContentAvailability(availability);
        return item;
    }

    @Test
    public void hidesMembersOnlyWhenEnabled() {
        assertTrue(ContentAvailabilityFilter.shouldHide(
                true, stream(ContentAvailability.MEMBERSHIP)));
    }

    @Test
    public void keepsMembersOnlyWhenDisabled() {
        assertFalse(ContentAvailabilityFilter.shouldHide(
                false, stream(ContentAvailability.MEMBERSHIP)));
    }

    @Test
    public void keepsAvailableAndPaidStreams() {
        assertFalse(ContentAvailabilityFilter.shouldHide(
                true, stream(ContentAvailability.AVAILABLE)));
        assertFalse(ContentAvailabilityFilter.shouldHide(
                true, stream(ContentAvailability.PAID)));
    }

    @Test
    public void keepsNonStreamItems() {
        final ChannelInfoItem channel = new ChannelInfoItem(0, "https://example.com", "test");
        assertFalse(ContentAvailabilityFilter.shouldHide(true, channel));
        assertFalse(ContentAvailabilityFilter.shouldHide(true, null));
    }
}
