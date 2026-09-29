// api/_lib/eventBuilder.js
// Builds the Google Calendar `requestBody` from our simple event shape.
// Pure — shared by calendar/create and the Canvas → Calendar mirror.

function addDays(dateStr, days) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/**
 * @param {{title:string,date:string,start_time?:string,end_time?:string,
 *          location?:string,description?:string,is_all_day?:boolean,
 *          utc_offset?:string,private_props?:object}} input
 *   utc_offset is the client's offset at the event time, e.g. "+10:00" or "Z"
 *   (Dart only knows offsets, not IANA zone names).
 */
function buildGoogleEvent(input) {
  const body = {
    summary: input.title,
    location: input.location || undefined,
    description: input.description || undefined,
  };

  if (input.is_all_day) {
    // Google's all-day end date is exclusive.
    body.start = { date: input.date };
    body.end = { date: addDays(input.date, 1) };
  } else {
    const offset = /^(Z|[+-]\d{2}:\d{2})$/.test(input.utc_offset || '') ? input.utc_offset : 'Z';
    const start = input.start_time || '09:00';
    const end = input.end_time && input.end_time > start ? input.end_time : start;
    body.start = { dateTime: `${input.date}T${start}:00${offset}` };
    body.end = { dateTime: `${input.date}T${end}:00${offset}` };
  }

  if (input.private_props) {
    body.extendedProperties = { private: input.private_props };
  }
  return body;
}

module.exports = { buildGoogleEvent, addDays };
