export async function redirectIfUnauthenticated<T>(
  getUser: () => Promise<{ data: { user: unknown } }>,
  redirect: () => T,
): Promise<T | undefined> {
  const { data } = await getUser()
  if (!data.user) return redirect()
}
