CE_NAMEMASK    = 0x0fff

CE_STAGEMASK   = 0x3000
CE_EXTENDED    = 0x4000
CE_VALID       = 0x8000
CE_STAGESHIFT  = 12

CE_UPDATE            = 1 << 16
CE_REMOVE            = 1 << 17
CE_UPTODATE          = 1 << 18
CE_ADDED             = 1 << 19
CE_HASHED            = 1 << 20
CE_WT_REMOVE         = 1 << 22
CE_CONFLICTED        = 1 << 23
CE_UNPACKED          = 1 << 24
CE_NEW_SKIP_WORKTREE = 1 << 25
CE_MATCHED           = 1 << 26
CE_UPDATE_IN_BASE    = 1 << 27
CE_STRIP_NAME        = 1 << 28
CE_INTENT_TO_ADD     = 1 << 29
CE_SKIP_WORKTREE     = 1 << 30
CE_EXTENDED2         = 1 << 31
CE_EXTENDED_FLAGS    = CE_INTENT_TO_ADD | CE_SKIP_WORKTREE

module CEFlags
  def self.explain flags
    result = []
    result << 'CE_STAGEMASK'     unless (flags & CE_STAGEMASK).zero?
    result << 'CE_EXTENDED'      unless (flags & CE_EXTENDED).zero?
    result << 'CE_VALID'         unless (flags & CE_VALID).zero?
    result << 'CE_INTENT_TO_ADD' unless (flags & CE_INTENT_TO_ADD).zero?
    result << 'CE_SKIP_WORKTREE' unless (flags & CE_SKIP_WORKTREE).zero?
    result.join ' | '
  end
end
