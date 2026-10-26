/*
 * SPDX-FileCopyrightText: 2026 NewPipe contributors <https://newpipe.net>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

package org.schabi.newpipe.util;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.preference.PreferenceManager;

import org.schabi.newpipe.R;
import org.schabi.newpipe.extractor.InfoItem;
import org.schabi.newpipe.extractor.stream.ContentAvailability;
import org.schabi.newpipe.extractor.stream.StreamInfoItem;

/**
 * Filters content that NewPipe cannot play because it requires a paid channel membership.
 */
public final class ContentAvailabilityFilter {
    private ContentAvailabilityFilter() {
    }

    /**
     * Whether members-only videos should currently be hidden.
     *
     * @param context any context, used to read the preference
     * @return {@code true} if members-only videos should be hidden (the default)
     */
    public static boolean isHideMembersOnlyEnabled(@NonNull final Context context) {
        return PreferenceManager.getDefaultSharedPreferences(context)
                .getBoolean(context.getString(R.string.hide_members_only_content), true);
    }

    /**
     * Whether an item should be removed from a list.
     *
     * @param hideMembersOnly whether the members-only filter is enabled
     * @param item the item to check, may be {@code null}
     * @return {@code true} if the item is a members-only video and the filter is enabled
     */
    public static boolean shouldHide(final boolean hideMembersOnly,
                                     @Nullable final InfoItem item) {
        if (!hideMembersOnly || !(item instanceof StreamInfoItem)) {
            return false;
        }
        return ((StreamInfoItem) item).getContentAvailability()
                == ContentAvailability.MEMBERSHIP;
    }

    /**
     * Whether an item should be removed from a list, respecting the current preference.
     *
     * @param context any context, used to read the preference
     * @param item the item to check, may be {@code null}
     * @return {@code true} if the item should be hidden
     */
    public static boolean shouldHide(@NonNull final Context context,
                                     @Nullable final InfoItem item) {
        return shouldHide(isHideMembersOnlyEnabled(context), item);
    }
}
