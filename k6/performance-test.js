import http from 'k6/http';
import { check } from 'k6';


// IMPORTANT: You should set the following environment variables before running the test
// export BASE_URL='http://localhost:4000'
// export API_KEY='vV1CWEhLQAdGBYaPy3ra0x9S21VVnSX2sD5uScf7/ZU='

export let options = {
  scenarios: {
    fixed_rate_test: {
      executor: 'constant-arrival-rate',
      rate: 10,
      timeUnit: '1s',
      duration: '60s',
      preAllocatedVUs: 50,
      maxVUs: 100,
    },
  },
  thresholds: {
    'http_req_duration{endpoint:/api/top-categories}': ['p(95)<300'],
    'http_req_duration{endpoint:/api/categories/*/expenses}': ['p(95)<300'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const API_KEY = __ENV.API_KEY;

export default function () {
  const headers = {
    'x-api-key': API_KEY,
    'Content-Type': 'application/json',
  };

  let resTop = http.get(`${BASE_URL}/api/top-categories`, {
    headers,
    tags: { endpoint: '/api/top-categories' },
  });

  check(resTop, { 'GET /api/top-categories responde 200': (r) => r.status === 200 });

  let categories = [];

  try {
    categories = resTop.json().data;
  } catch (e) {
    categories = [];
  }

  if (!Array.isArray(categories) || categories.length === 0) return;

  const randomCategory = categories[Math.floor(Math.random() * categories.length)];
  const categoryId = randomCategory.id;

  let resExpenses = http.get(
    `${BASE_URL}/api/categories/${categoryId}/expenses?date_from=2023-01-01&date_to=2026-12-31`,
    {
      headers,
      tags: { endpoint: `/api/categories/*/expenses` },
    }
  );

  check(resExpenses, {
    'GET /api/categories/:id/expenses responde 200': (r) => r.status === 200,
  });
}