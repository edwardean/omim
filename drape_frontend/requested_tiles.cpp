#include "drape_frontend/requested_tiles.hpp"

namespace df
{

void RequestedTiles::Set(ScreenBase const & screen, bool have3dBuildings, bool forceRequest,
                         TTilesCollection && tiles)
{
  lock_guard<mutex> lock(m_mutex);
  m_tiles = move(tiles);
  m_screen = screen;
  m_have3dBuildings = have3dBuildings;
  m_forceRequest = forceRequest;
}

TTilesCollection RequestedTiles::GetTiles()
{
  TTilesCollection tiles;
  {
    lock_guard<mutex> lock(m_mutex);
    m_tiles.swap(tiles);
  }
  return tiles;
}

void RequestedTiles::GetParams(ScreenBase & screen, bool & have3dBuildings, bool & forceRequest)
{
  lock_guard<mutex> lock(m_mutex);
  screen = m_screen;
  have3dBuildings = m_have3dBuildings;
  forceRequest = m_forceRequest;
}

bool RequestedTiles::CheckTileKey(TileKey const & tileKey) const
{
  lock_guard<mutex> lock(m_mutex);
  if (m_tiles.empty())
    return true;

  return m_tiles.find(tileKey) != m_tiles.end();
}

}  // namespace df
