"""Endpoints de agregação e analytics.

GET /stats/volume?groupBy=week   — volume total por período
GET /stats/muscle-groups         — volume por grupo muscular
GET /stats/heatmap?from&to       — matriz data x grupo muscular x volume
"""

# TODO(Sprint 3): get_volume_stats(group_by, user=Depends(get_current_user))
# TODO(Sprint 3): get_muscle_group_volume(user=Depends(get_current_user))
# TODO(Sprint 5): get_heatmap(date_from, date_to, user=Depends(get_current_user)) — cache Redis
