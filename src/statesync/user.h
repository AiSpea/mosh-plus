/*
    Mosh: the mobile shell
    Copyright 2012 Keith Winstein

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give
    permission to link the code of portions of this program with the
    OpenSSL library under certain conditions as described in each
    individual source file, and distribute linked combinations including
    the two.

    You must obey the GNU General Public License in all respects for all
    of the code used other than OpenSSL. If you modify file(s) with this
    exception, you may extend this exception to your version of the
    file(s), but you are not obligated to do so. If you do not wish to do
    so, delete this exception statement from your version. If you delete
    this exception statement from all source files in the program, then
    also delete it here.
*/

#ifndef USER_HPP
#define USER_HPP

#include <cassert>
#include <cstdint>
#include <deque>
#include <list>
#include <string>

#include "src/terminal/parseraction.h"

namespace Network {
enum UserEventType
{
  UserByteType = 0,
  ResizeType = 1,
  MouseType = 2
};

struct MouseEvent
{
  enum Type
  {
    MOVE = 0,
    CLICK = 1,
    SCROLL_UP = 2,
    SCROLL_DOWN = 3
  };

  Type type;
  uint32_t x;
  uint32_t y;
  bool release;
  uint32_t button;
  uint32_t encoded;

  MouseEvent( Type s_type = MOVE,
              uint32_t s_x = 0,
              uint32_t s_y = 0,
              bool s_release = false,
              uint32_t s_button = 0,
              uint32_t s_encoded = 0 )
    : type( s_type ), x( s_x ), y( s_y ), release( s_release ), button( s_button ), encoded( s_encoded )
  {}

  bool operator==( const MouseEvent& other ) const
  {
    return ( type == other.type ) && ( x == other.x ) && ( y == other.y ) && ( release == other.release )
           && ( button == other.button ) && ( encoded == other.encoded );
  }
};

class UserEvent
{
public:
  UserEventType type;
  Parser::UserByte userbyte;
  Parser::Resize resize;
  MouseEvent mouse;

  UserEvent( const Parser::UserByte& s_userbyte )
    : type( UserByteType ), userbyte( s_userbyte ), resize( -1, -1 ), mouse()
  {}
  UserEvent( const Parser::Resize& s_resize ) : type( ResizeType ), userbyte( 0 ), resize( s_resize ), mouse() {}
  UserEvent( const MouseEvent& s_mouse ) : type( MouseType ), userbyte( 0 ), resize( -1, -1 ), mouse( s_mouse ) {}

private:
  UserEvent();

public:
  bool operator==( const UserEvent& x ) const
  {
    return ( type == x.type ) && ( userbyte == x.userbyte ) && ( resize == x.resize ) && ( mouse == x.mouse );
  }
};

class UserStream
{
private:
  std::deque<UserEvent> actions;

public:
  UserStream() : actions() {}

  void push_back( const Parser::UserByte& s_userbyte ) { actions.push_back( UserEvent( s_userbyte ) ); }
  void push_back( const Parser::Resize& s_resize ) { actions.push_back( UserEvent( s_resize ) ); }
  void push_back( const MouseEvent& s_mouse ) { actions.push_back( UserEvent( s_mouse ) ); }

  bool empty( void ) const { return actions.empty(); }
  size_t size( void ) const { return actions.size(); }
  const Parser::Action& get_action( unsigned int i ) const;
  const UserEvent& get_event( unsigned int i ) const { return actions[i]; }

  /* interface for Network::Transport */
  void subtract( const UserStream* prefix );
  std::string diff_from( const UserStream& existing ) const;
  std::string init_diff( void ) const { return diff_from( UserStream() ); };
  void apply_string( const std::string& diff );
  bool operator==( const UserStream& x ) const { return actions == x.actions; }

  bool compare( const UserStream& ) { return false; }
};
}

#endif
