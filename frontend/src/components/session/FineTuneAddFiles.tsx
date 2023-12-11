import React, { FC, useState, useEffect, useCallback } from 'react'
import Typography from '@mui/material/Typography'
import Button from '@mui/material/Button'
import Grid from '@mui/material/Grid'

import NavigateNextIcon from '@mui/icons-material/NavigateNext'
import AddIcon from '@mui/icons-material/Add'

import useApi from '../../hooks/useApi'
import Window from '../widgets/Window'
import UploadingOverlay from '../widgets/UploadingOverlay'
import FineTuneImageInputs from './FineTuneImageInputs'
import FineTuneImageLabels from './FineTuneImageLabels'
import FineTuneTextInputs from './FineTuneTextInputs'

import useSnackbar from '../../hooks/useSnackbar'
import useFinetuneInputs from '../../hooks/useFinetuneInputs'

import {
  ISession,
  SESSION_TYPE_IMAGE,
} from '../../types'

export const FineTuneAddFiles: FC<{
  session: ISession,
  interactionID: string,
  onCancel: () => void,
}> = ({
  session,
  interactionID,
  onCancel,
}) => {
  const snackbar = useSnackbar()
  const api = useApi()
  const inputs = useFinetuneInputs()
  const [ editMode, setEditMode ] = useState(false)
  
  return (
    <>
      <Grid container spacing={ 0 }>
        <Grid item sm={ 12 } md={ 6 } sx={{pr:2}}>
          <Typography gutterBottom>
            You have a chance to add more files to the training data or you can start the training process.
          </Typography>
        </Grid>
        <Grid item sm={ 12 } md={ 6 } sx={{
          textAlign: 'right',
          pt: 2,
        }}>
          {/* <Button
            variant="contained"
            color="primary"
            size="small"
            sx={{
              mr: 2,
            }}
            endIcon={<AddIcon />}
            onClick={ () => setEditMode(true) }
          >
            Add Files
          </Button> */}
          <Button
            variant="contained"
            color="secondary"
            size="small"
            endIcon={<NavigateNextIcon />}
            onClick={ () => {} }
          >
            Start Training
          </Button>
        </Grid>

      </Grid>
      
    </>
  )  
}

export default FineTuneAddFiles