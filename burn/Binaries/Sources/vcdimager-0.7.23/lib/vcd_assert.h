/*
    $Id: vcd_assert.h,v 1.2 2003/11/10 11:57:52 rocky Exp $

    Copyright (C) 2000 Herbert Valerio Riedel <hvr@gnu.org>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef __VCD_ASSERT_H__
#define __VCD_ASSERT_H__

#if defined(__GNUC__)

#include <libvcd/types.h>
#include <libvcd/logging.h>

#define vcd_assert(expr) \
 { \
   if (GNUC_UNLIKELY (!(expr))) vcd_log (VCD_LOG_ASSERT, \
     "file %s: line %d (%s): assertion failed: (%s)", \
     __FILE__, __LINE__, __PRETTY_FUNCTION__, #expr); \
 } 

#define vcd_assert_not_reached() \
 { \
   vcd_log (VCD_LOG_ASSERT, \
     "file %s: line %d (%s): should not be reached", \
     __FILE__, __LINE__, __PRETTY_FUNCTION__); \
 }

#else /* non GNU C */

#include <assert.h>

#define vcd_assert(expr) \
 assert(expr)

#define vcd_assert_not_reached() \
 assert(0)

#endif

#endif /* __VCD_ASSERT_H__ */
