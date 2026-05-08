import { useState, useEffect, useRef } from 'react'
import { useLocation } from 'react-router-dom'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function Messaging() {
  const [activeChat, setActiveChat] = useState(null)
  const [conversations, setConversations] = useState([])
  const [messages, setMessages] = useState([])
  const [newMsg, setNewMsg] = useState('')
  const [loading, setLoading] = useState(true)
  const bottomRef = useRef(null)
  const location = useLocation()

  // Load conversations from backend
  const fetchConversations = async () => {
    try {
      const res = await fetch(`${API_URL}/messages/conversations`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) setConversations(await res.json())
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchConversations()
  }, [])

  // Handle incoming chat requests from Networking page
  useEffect(() => {
    if (location.state?.chatUser) {
      const u = location.state.chatUser;
      const initials = (u.name || 'U').split(' ').map(n => n[0]).join('').toUpperCase().slice(0,2)
      
      const chatTarget = {
        id: u.id,
        name: u.name,
        company: u.company || 'Member',
        initials: initials
      }
      
      openChat(chatTarget)
      // Clear the state so refreshing doesn't keep reopening the chat
      window.history.replaceState({}, '')
    }
  }, [location.state])

  const openChat = async (target) => {
    setActiveChat(target)
    setMessages([])
    try {
      const res = await fetch(`${API_URL}/messages/${target.id}`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) setMessages(await res.json())
    } catch (e) {
      console.error(e)
    }
  }

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const sendMessage = async () => {
    if (!newMsg.trim() || !activeChat) return
    const textToSend = newMsg
    setNewMsg('')

    try {
      const res = await fetch(`${API_URL}/messages/${activeChat.id}`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` 
        },
        body: JSON.stringify({ text: textToSend })
      })

      if (res.ok) {
        const savedMsg = await res.json()
        setMessages(prev => [...prev, savedMsg])
        fetchConversations() // refresh the list
      }
    } catch (e) {
      console.error('Failed to send message', e)
    }
  }

  return (
    <AppLayout title="Messages" hideSearch>
      <div style={{ height: 'calc(100vh - 120px)', height: 'calc(100svh - 120px)', display: 'flex', flexDirection: 'column' }}>

        {!activeChat ? (
          // Conversations List View
          <div className="feed-card" style={{ flex: 1, padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column', border: 'none', borderRadius: 12 }}>
            <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--border-subtle)' }}>
              <div style={{ position: 'relative' }}>
                <span className="material-symbols-outlined" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem' }}>search</span>
                <input
                  type="text"
                  placeholder="Search messages..." autoComplete="off"
                  style={{ width: '100%', padding: '10px 12px 10px 38px', border: '1.5px solid var(--border-default)', borderRadius: 10, background: 'var(--bg-base)', color: 'var(--text-primary)', fontSize: '0.9rem' }}
                />
              </div>
            </div>

            {conversations.length === 0 ? (
              // Empty state
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12, padding: '40px 24px', textAlign: 'center' }}>
                <div style={{ width: 60, height: 60, borderRadius: '50%', background: 'rgba(240,130,50,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: 'var(--brand-primary)' }}>chat_bubble</span>
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-primary)', marginBottom: 4 }}>No messages</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', lineHeight: 1.5, maxWidth: 240, margin: '0 auto' }}>
                    Conversations with secretariat and members appear here.
                  </div>
                </div>
              </div>
            ) : (
              <div style={{ flex: 1, overflowY: 'auto' }}>
                {conversations.map(conv => (
                  <div
                    key={conv.id}
                    onClick={() => openChat(conv)}
                    style={{ display: 'flex', gap: 12, padding: '14px 16px', cursor: 'pointer', borderBottom: '1px solid var(--border-subtle)', transition: 'background 0.2s' }}
                  >
                    <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'var(--brand-primary)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.9rem', fontWeight: 800, flexShrink: 0 }}>
                      {conv.initials}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}>
                        <span style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{conv.name}</span>
                        <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>{conv.time}</span>
                      </div>
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{conv.lastMsg}</div>
                    </div>
                    {conv.unread > 0 && (
                      <div style={{ width: 20, height: 20, borderRadius: '50%', background: 'var(--brand-primary)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.65rem', fontWeight: 800, flexShrink: 0, marginTop: 4 }}>
                        {conv.unread}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          // Active Chat View
          <div className="feed-card" style={{ flex: 1, padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column', border: 'none', borderRadius: 12 }}>
            {/* Chat Header */}
            <div style={{ padding: '10px 12px', borderBottom: '1px solid var(--border-subtle)', display: 'flex', alignItems: 'center', gap: 10 }}>
              <button onClick={() => setActiveChat(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', padding: 6 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>arrow_back_ios_new</span>
              </button>
              <div style={{ width: 34, height: 34, borderRadius: '50%', background: 'var(--brand-primary)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.8rem', fontWeight: 800, flexShrink: 0 }}>
                {activeChat.initials}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{activeChat.name}</div>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{activeChat.company}</div>
              </div>
            </div>

            {/* Messages */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '12px', display: 'flex', flexDirection: 'column', gap: 10, background: 'var(--bg-base)' }}>
              {messages.length === 0 && (
                <div style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem', marginTop: 32 }}>
                  Say hello to {activeChat.name.split(' ')[0]}!
                </div>
              )}
              {messages.map(msg => (
                <div key={msg.id} style={{ display: 'flex', justifyContent: msg.from === 'me' ? 'flex-end' : 'flex-start' }}>
                  <div style={{
                    maxWidth: '85%', padding: '10px 14px',
                    borderRadius: msg.from === 'me' ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
                    background: msg.from === 'me' ? 'var(--brand-primary)' : 'var(--bg-elevated)',
                    color: msg.from === 'me' ? '#fff' : 'var(--text-primary)',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
                    fontSize: '0.85rem', lineHeight: 1.4
                  }}>
                    {msg.text}
                    <div style={{ fontSize: '0.6rem', opacity: 0.7, marginTop: 4, textAlign: 'right' }}>{msg.time}</div>
                  </div>
                </div>
              ))}
              <div ref={bottomRef} />
            </div>

            {/* Input */}
            <div style={{ padding: '10px 12px', borderTop: '1px solid var(--border-subtle)', display: 'flex', gap: 10, background: 'var(--bg-surface)' }}>
              <input
                type="text"
                value={newMsg}
                onChange={e => setNewMsg(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && sendMessage()}
                placeholder="Type..."
                style={{ flex: 1, padding: '10px 14px', border: '1.5px solid var(--border-default)', borderRadius: 20, background: 'var(--bg-base)', color: 'var(--text-primary)', fontSize: '0.9rem', outline: 'none' }}
              />
              <button onClick={sendMessage} className="btn btn-primary" style={{ width: 40, height: 40, borderRadius: '50%', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', marginLeft: 2 }}>send</span>
              </button>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
