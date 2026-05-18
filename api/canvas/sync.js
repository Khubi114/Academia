const { supabaseAdmin } = require('../utils/supabase');

module.exports = async (req, res) => {
  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    const { userId } = req.body || {};
    if (!userId) return res.status(400).json({ error: 'Missing userId' });

    const { data: settings, error: settingsError } = await supabaseAdmin
      .from('user_settings')
      .select('canvas_token, canvas_domain')
      .eq('user_id', userId)
      .single();

    if (settingsError || !settings?.canvas_token) {
      return res.status(401).json({ error: 'No Canvas connection found' });
    }

    const { canvas_token, canvas_domain } = settings;
    const domain = canvas_domain || 'canvas.instructure.com';

    const coursesRes = await fetch(`https://${domain}/api/v1/courses?enrollment_state=active&per_page=50`, {
      headers: { Authorization: `Bearer ${canvas_token}` }
    });
    const courses = await coursesRes.json();

    if (!Array.isArray(courses)) {
      throw new Error('Failed to fetch Canvas courses');
    }

    const activeCourseIds = courses.filter(c => c.id).map(c => c.id);
    let allAssignments = [];

    for (const courseId of activeCourseIds) {
      const assignmentsRes = await fetch(`https://${domain}/api/v1/courses/${courseId}/assignments?per_page=50`, {
        headers: { Authorization: `Bearer ${canvas_token}` }
      });
      const assignments = await assignmentsRes.json();
      if (Array.isArray(assignments)) {
        const course = courses.find(c => c.id === courseId);
        assignments.forEach(a => {
          allAssignments.push({
            id: a.id.toString(),
            user_id: userId,
            title: a.name,
            course_name: course.name,
            course_code: course.course_code || '',
            due_date: a.due_at || '',
            status: a.has_submitted_submissions ? 'submitted' : (new Date(a.due_at) < new Date() ? 'overdue' : 'pending'),
            points: a.points_possible || 0,
            created_at: new Date().toISOString()
          });
        });
      }
    }

    if (allAssignments.length > 0) {
      const { error: upsertError } = await supabaseAdmin
        .from('assignments')
        .upsert(allAssignments, { onConflict: 'id,user_id' });
      if (upsertError) throw upsertError;
    }

    return res.status(200).json({ success: true, assignmentsSynced: allAssignments.length });
  } catch (error) {
    console.error('Canvas Sync Error:', error);
    return res.status(500).json({ error: error.message });
  }
};
